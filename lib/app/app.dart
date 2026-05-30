import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_config.dart';
import 'app_theme.dart';
import '../di/providers.dart';
import '../domain/saved_sync_url.dart';
import '../infrastructure/firestore/local_data_migrator.dart';
import '../presentation/search_page.dart';
import '../presentation/widgets/apk_update_dialog.dart';
import '../presentation/widgets/auto_sync_merge_dialog.dart';
import '../presentation/widgets/web_cookie_auth.dart';

class DictionaryApp extends ConsumerStatefulWidget {
  const DictionaryApp({super.key});

  @override
  ConsumerState<DictionaryApp> createState() => _DictionaryAppState();
}

class _DictionaryAppState extends ConsumerState<DictionaryApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kIsWeb) await _tryInitFromCookie();
      _listenForMigration();
      // 起動時にサイレントで Sheets アクセストークンを取得（再起動後の自動復元）
      if (!kIsWeb) await _trySilentGoogleToken();
      // SharedPreferences の読み込みを待ってから自動同期チェック
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) await _runPendingAutoSync();
      if (mounted && AppConfig.isApkBuild) await _checkForUpdate();
    });
  }

  // nzw.jp バックエンドの JWT クッキー（ログインページで設定）があれば
  // ユーザー情報を復元する。
  Future<void> _tryInitFromCookie() async {
    final profile = readNzwJpAuthFromBrowser();
    if (profile == null) return;
    ref.read(webCookieUserProvider.notifier).state = profile;
    try {
      final raw = readNzwJpToken();
      if (raw != null) {
        await ref.read(nzwJpAuthRepositoryProvider).saveJwt(raw);
      }
    } catch (_) {}
  }

  // 初回サインイン時に localStorage データを Firestore へ移行する。
  // Firebase Auth はセッション復元を自動管理するためここでの初期化は不要。
  void _listenForMigration() {
    ref.listenManual(firebaseUserProvider, (prev, next) async {
      final uid = next.valueOrNull?.uid;
      if (uid == null) return;
      // prev が null → next が非 null のとき（サインイン直後 or 起動時の復元）
      if (prev?.valueOrNull == null) {
        await LocalDataMigrator.migrateIfNeeded(uid);
      }
    });
  }

  // ─── 自動同期 ──────────────────────────────────────────────────────────────

  Future<void> _runPendingAutoSync() async {
    if (kIsWeb) return; // Web は手動同期のみ

    final savedUrls = ref.read(savedUrlsProvider);
    final dueUrls = savedUrls.where(_isSyncDue).toList();
    if (dueUrls.isEmpty) return;

    // トークン取得（既存 or サイレントサインイン試行）
    String? token = ref.read(sheetsAccessTokenProvider);
    token ??= await _trySilentGoogleToken();

    for (final savedUrl in dueUrls) {
      if (!mounted) return;

      if (token == null) {
        _showSnackBar('「${savedUrl.title}」の自動同期: Googleサインインが必要です');
        continue;
      }

      try {
        final result = await ref.read(autoSyncUseCaseProvider).execute(savedUrl);
        await ref
            .read(savedUrlsProvider.notifier)
            .updateLastAutoSyncAt(savedUrl.id);

        if (savedUrl.autoSyncMode == AutoSyncMode.mergeConfirm &&
            result.hasPendingAction) {
          _showConflictBanner(savedUrl, result);
        } else if (result.addedFromSheet > 0) {
          _showSnackBar(
              '「${savedUrl.title}」: ${result.addedFromSheet}件追加しました');
        } else if (result.skippedDueToHeader) {
          _showSnackBar('「${savedUrl.title}」: ヘッダーを認識できず自動同期をスキップしました');
        }
      } catch (e) {
        _showSnackBar('「${savedUrl.title}」自動同期に失敗しました: $e');
      }
    }
  }

  void _showSnackBar(String message, {Duration? duration}) {
    _scaffoldMessengerKey.currentState?.clearSnackBars();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConflictBanner(SavedSyncUrl savedUrl, AutoSyncResult result) {
    final count = result.conflicts.length +
        result.newEntriesFromSheet.length +
        result.manualEntriesToExport.length;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('「${savedUrl.title}」: $count件の確認が必要です'),
        duration: const Duration(minutes: 10),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '確認',
          onPressed: () {
            final context = _navigatorKey.currentContext;
            if (context == null) return;
            showDialog<void>(
              context: context,
              builder: (_) => AutoSyncMergeDialog(
                savedUrl: savedUrl,
                result: result,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Google Sign-In v7 のサイレント認証で Sheets access token を取得する。
  /// 過去にサインイン済みでなければ null を返す（UI は表示しない）。
  Future<String?> _trySilentGoogleToken() async {
    try {
      // attemptLightweightAuthentication() はプラットフォームが対応していない場合 null を返す
      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (future == null) return null;

      final account = await future;
      if (account == null) return null;

      // Sheets スコープのトークンをUIなしで取得
      const sheetsScope = 'https://www.googleapis.com/auth/spreadsheets';
      final authz = await account.authorizationClient
          .authorizationForScopes([sheetsScope]);
      if (authz == null) return null;

      final token = authz.accessToken;
      if (mounted) {
        ref.read(sheetsAccessTokenProvider.notifier).state = token;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await ref.read(updateInfoProvider.future);
      if (!mounted || info == null || !info.isUpdateAvailable) return;
      final ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await showDialog<void>(
        context: ctx,
        barrierDismissible: !info.isForceUpdate,
        builder: (_) => ApkUpdateDialog(info: info),
      );
    } catch (_) {}
  }

  static bool _isSyncDue(SavedSyncUrl url) {
    if (url.autoSyncSchedule == AutoSyncSchedule.none) return false;
    final last = url.lastAutoSyncAt;
    if (last == null) return true;
    final now = DateTime.now();
    return switch (url.autoSyncSchedule) {
      AutoSyncSchedule.daily => now.difference(last).inHours >= 24,
      AutoSyncSchedule.weekly => now.difference(last).inDays >= 7,
      AutoSyncSchedule.none => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LangBridge',
      theme: buildAppTheme(),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      navigatorKey: _navigatorKey,
      home: const SearchPage(),
    );
  }
}
