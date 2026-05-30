import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app/app_config.dart';
import '../di/providers.dart';
import '../domain/dictionary_entry.dart';
import 'ai_mode_settings_page.dart';
import 'dict_link_settings_page.dart';
import 'sync_page.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/apk_update_dialog.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _authBusy = false;
  String? _authError;
  int _dataSectionEpoch = 0;

  Future<void> _signIn() async {
    setState(() {
      _authBusy = true;
      _authError = null;
    });
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('https://www.googleapis.com/auth/spreadsheets');
        final cred = await FirebaseAuth.instance.signInWithPopup(provider);
        final oAuth = cred.credential as OAuthCredential?;
        if (oAuth?.accessToken != null) {
          ref.read(sheetsAccessTokenProvider.notifier).state = oAuth!.accessToken;
        }
      } else {
        // Custom Tab (signInWithProvider) は "missing initial state" エラーが出るため
        // ネイティブ Google Sign-In を使用する
        const sheetsScope = 'https://www.googleapis.com/auth/spreadsheets';
        final account = await GoogleSignIn.instance.authenticate(
          scopeHint: [sheetsScope],
        );
        final authz = await account.authorizationClient.authorizeScopes([sheetsScope]);
        final credential = GoogleAuthProvider.credential(
          idToken: account.authentication.idToken,
          accessToken: authz.accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        ref.read(sheetsAccessTokenProvider.notifier).state = authz.accessToken;
      }
    } on GoogleSignInException catch (e) {
      if (mounted) {
        setState(() => _authError = 'Google Sign-In エラー: ${e.code.name}');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _authError = '${e.code}: ${e.message ?? ""}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _authError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _authBusy = true);
    try {
      await Future.wait([
        FirebaseAuth.instance.signOut(),
        if (!kIsWeb) GoogleSignIn.instance.signOut(),
      ]);
      ref.read(sheetsAccessTokenProvider.notifier).state = null;
      ref.read(webCookieUserProvider.notifier).state = null;
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Widget _loginDetailsExpansion({
    required ThemeData theme,
    required Color backgroundColor,
    required String title,
    required String detailText,
  }) {
    return Theme(
      data: theme.copyWith(
        listTileTheme: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 0,
        ),
      ),
      child: Material(
        color: backgroundColor,
        child: ExpansionTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 2, bottom: 2),
          collapsedShape: const RoundedRectangleBorder(),
          shape: const RoundedRectangleBorder(),
          title: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Text(
              detailText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userInfo = ref.watch(currentUserInfoProvider);
    final cookieUser = ref.watch(webCookieUserProvider);
    final isSignedIn = userInfo != null || cookieUser != null;
    final displayEmail = userInfo?.email ?? cookieUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          const AccountMenuButton(showGoHome: true),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          // ── アップデート通知（APKビルドのみ）──────────────
          if (AppConfig.isApkBuild)
            ref.watch(updateInfoProvider).when(
              data: (info) {
                if (info == null || !info.isUpdateAvailable) {
                  return const SizedBox.shrink();
                }
                final isForce = info.isForceUpdate;
                final fgColor = isForce
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    color: isForce
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer,
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        barrierDismissible: !isForce,
                        builder: (_) => ApkUpdateDialog(info: info),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          children: [
                            Icon(
                              isForce
                                  ? Icons.warning_amber_rounded
                                  : Icons.system_update_alt_rounded,
                              size: 18,
                              color: fgColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isForce
                                        ? '必須アップデートがあります'
                                        : 'アップデートが利用可能です',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: fgColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'v${AppConfig.appVersion} → v${info.latestVersion}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: fgColor),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: fgColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // ── Google アカウント ──────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Google アカウント',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isSignedIn) ...[
                    Text(
                      'ログイン中: ${displayEmail ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _authBusy ? null : _signOut,
                      icon: _authBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      label: const Text('ログアウト'),
                    ),
                  ] else ...[
                    Text(
                      'ログインすると Google Sheets との同期が使えます。',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                    if (AppConfig.useRealSheets) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _authBusy ? null : _signIn,
                        icon: _authBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Googleでログイン'),
                      ),
                    ],
                    if (_authError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _authError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── AI アシスト ───────────────────────────────
          if (isSignedIn) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'AI アシスト',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _GeminiUsageSection(),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.tune_outlined, size: 20),
                    title: const Text('AI モード設定'),
                    subtitle: const Text('モードの順序・固定・言語リストを管理'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AiModeSettingsPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── データ ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'データ',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.sync_alt,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Google Sheets で同期'),
              subtitle: const Text(
                'スプレッドシートから単語を取り込んだり、端末の単語を書き出したりできます。',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SyncPage(),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _dataSectionEpoch++);
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── 辞書設定 ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '辞書設定',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.menu_book_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('外部辞書の設定'),
              subtitle: const Text('検索結果に表示する外部辞書リンクのON/OFFや並び順を変更します。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DictLinkSettingsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── データ管理 ───────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'データ管理',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: _DataManagementSection(key: ValueKey(_dataSectionEpoch)),
          ),
          const SizedBox(height: 24),

          // ── よくある質問 ────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'よくある質問',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _loginDetailsExpansion(
                    theme: theme,
                    backgroundColor: Colors.transparent,
                    title: 'Q. なぜ Google ログインが必要ですか？',
                    detailText:
                        'A. ブラウザで「リンクを知っている全員が閲覧可」のシートを開けることと、'
                        'アプリが Google Sheets API でデータを読み取ることは別です。'
                        '本アプリは Sheets API を使う実装のため、共有を広くしていても OAuth（Google でログイン）による許可が必要です。'
                        '（API キーだけの匿名アクセスは行っていません。）',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'v${AppConfig.appVersion}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── データ管理セクション ──────────────────────────────────────

class _DataManagementSection extends ConsumerStatefulWidget {
  const _DataManagementSection({super.key});

  @override
  ConsumerState<_DataManagementSection> createState() =>
      _DataManagementSectionState();
}

class _DataManagementSectionState
    extends ConsumerState<_DataManagementSection> {
  List<DictionaryEntry>? _entries;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final all = await ref.read(userRepositoryProvider).listAll();
    if (!mounted) return;
    setState(() {
      _entries = List.from(all);
      _loading = false;
    });
  }

  String _fmt(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}'
      ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// importSessionId ごとにグループ化。セッションIDなしは「不明」扱い。
  List<_ImportSession> _buildSessions(List<DictionaryEntry> entries) {
    final map = <String, List<DictionaryEntry>>{};
    for (final e in entries) {
      final key = e.importSessionId ?? '_unknown';
      (map[key] ??= []).add(e);
    }
    final sessions = map.entries.map((kv) {
      final sessionEntries = kv.value;
      final first = sessionEntries.first;
      return _ImportSession(
        id: kv.key,
        sourceUrl: first.sourceUrl,
        importedAt: first.createdAt,
        count: sessionEntries.length,
      );
    }).toList()
      ..sort((a, b) {
        if (a.importedAt == null && b.importedAt == null) return 0;
        if (a.importedAt == null) return 1;
        if (b.importedAt == null) return -1;
        return b.importedAt!.compareTo(a.importedAt!);
      });
    return sessions;
  }

  Future<void> _deleteSession(_ImportSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取込データの削除'),
        content: Text(
          '${session.importedAt != null ? _fmt(session.importedAt!) : "不明"} に取り込んだ'
          ' ${session.count} 件を削除しますか？\nこの操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      if (session.id == '_unknown') {
        final all = await ref.read(userRepositoryProvider).listAll();
        final ids = all
            .where((e) =>
                e.importSessionId == null &&
                e.sourceType == EntrySourceType.userSheet)
            .map((e) => e.id)
            .toList();
        await ref.read(userRepositoryProvider).deleteManyByIds(ids);
      } else {
        await ref.read(userRepositoryProvider).deleteBySessionId(session.id);
      }
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${session.count} 件を削除しました'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('削除に失敗しました: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteAll() async {
    final entries = _entries;
    if (entries == null || entries.isEmpty) return;
    final count = entries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全データのリセット'),
        content: Text(
          '$count 件をすべて削除しますか？\nこの操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('全て削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(userRepositoryProvider).deleteAll();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count 件を削除しました'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('削除に失敗しました: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteAllManual() async {
    final entries = _entries;
    if (entries == null) return;
    final manualEntries =
        entries.where((e) => e.sourceType == EntrySourceType.manual).toList();
    if (manualEntries.isEmpty) return;
    final count = manualEntries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手動登録データの削除'),
        content: Text(
          '手動で登録した単語 $count 件をすべて削除しますか？\nこの操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .deleteManyByIds(manualEntries.map((e) => e.id).toList());
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count 件を削除しました'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('削除に失敗しました: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _deleting) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final entries = _entries ?? [];
    final sheetEntries = entries
        .where((e) => e.sourceType == EntrySourceType.userSheet)
        .toList();
    final manualEntries = entries
        .where((e) => e.sourceType == EntrySourceType.manual)
        .toList();
    final sessions = _buildSessions(sheetEntries);

    // 最新日時を求めるヘルパー
    DateTime? latestDate(Iterable<DateTime?> dates) {
      DateTime? result;
      for (final d in dates) {
        if (d != null && (result == null || d.isAfter(result))) result = d;
      }
      return result;
    }

    final latestAll = latestDate(
        entries.map((e) => e.updatedAt ?? e.createdAt));
    final latestSheet = latestDate(sheetEntries.map((e) => e.updatedAt ?? e.createdAt));
    final latestManual = latestDate(manualEntries.map((e) => e.updatedAt ?? e.createdAt));

    // セッションが複数ある場合のみ個別削除行を表示（1件のときは親行と同じ情報になるため非表示）
    final showSessionRows = sessions.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 全データ ────────────────────────────────
        _DataRow(
          icon: Icons.storage_outlined,
          label: '全データ',
          count: entries.length,
          date: latestAll != null ? _fmt(latestAll) : null,
          action: entries.isNotEmpty
              ? _DeleteButton(label: '全てリセット', onPressed: _deleteAll)
              : null,
          topPadding: 14,
        ),
        const Divider(height: 1),

        // ── スプレッドシート取込 ─────────────────────
        _DataRow(
          icon: Icons.table_rows_outlined,
          label: 'スプレッドシート取込',
          count: sheetEntries.length,
          date: latestSheet != null ? _fmt(latestSheet) : null,
          // 単一セッションのときはここで削除ボタンを表示
          action: (!showSessionRows && sessions.isNotEmpty)
              ? _DeleteButton(
                  label: '削除',
                  onPressed: () => _deleteSession(sessions.first),
                )
              : null,
        ),
        // 複数セッションのみ個別行を表示
        if (showSessionRows) ...[
          for (final session in sessions) ...[
            const Divider(height: 1, indent: 16),
            _SessionTile(
              session: session,
              fmt: _fmt,
              onDelete: () => _deleteSession(session),
            ),
          ],
          const SizedBox(height: 4),
        ],

        const Divider(height: 1),

        // ── 手動登録 ────────────────────────────────
        _DataRow(
          icon: Icons.edit_outlined,
          label: '手動登録',
          count: manualEntries.length,
          date: latestManual != null ? _fmt(latestManual) : null,
          action: manualEntries.isNotEmpty
              ? _DeleteButton(label: '全削除', onPressed: _deleteAllManual)
              : null,
          bottomPadding: 12,
        ),
      ],
    );
  }
}

// ── 共通の1行ウィジェット ─────────────────────────────────────

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.count,
    this.date,
    this.action,
    this.topPadding = 10,
    this.bottomPadding = 10,
  });

  final IconData icon;
  final String label;
  final int count;
  final String? date;
  final Widget? action;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 8, bottomPadding),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                Text(
                  '$count 件${date != null ? '  $date' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.delete_outline_rounded, size: 16, color: cs.error),
      label: Text(label, style: TextStyle(color: cs.error, fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ImportSession {
  const _ImportSession({
    required this.id,
    required this.count,
    this.sourceUrl,
    this.importedAt,
  });
  final String id;
  final int count;
  final String? sourceUrl;
  final DateTime? importedAt;
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.fmt,
    required this.onDelete,
  });

  final _ImportSession session;
  final String Function(DateTime) fmt;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeLabel = session.importedAt != null
        ? fmt(session.importedAt!)
        : '取込日時不明';
    final urlLabel = session.sourceUrl != null
        ? _trimUrl(session.sourceUrl!)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.count} 件  $timeLabel',
                  style: theme.textTheme.bodySmall,
                ),
                if (urlLabel != null)
                  Text(
                    urlLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'この取込データを削除',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _trimUrl(String url) {
    // スプレッドシートIDの前後を省略して短く表示
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments;
    final dIdx = segments.indexOf('d');
    if (dIdx >= 0 && dIdx + 1 < segments.length) {
      final id = segments[dIdx + 1];
      return 'ID: ${id.length > 12 ? '${id.substring(0, 12)}…' : id}';
    }
    return uri.host;
  }
}

class _GeminiUsageSection extends ConsumerStatefulWidget {
  const _GeminiUsageSection();

  @override
  ConsumerState<_GeminiUsageSection> createState() => _GeminiUsageSectionState();
}

class _GeminiUsageSectionState extends ConsumerState<_GeminiUsageSection> {
  ({int used, int remaining, int limit, String? resetDate})? _usage;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final authRepo = ref.read(nzwJpAuthRepositoryProvider);
      final apiClient = ref.read(nzwJpApiClientProvider);

      var jwt = await authRepo.getValidJwt();
      if (jwt == null) {
        // nzw.jp は Google ID token を期待しているため、GoogleSignIn 経由で取得する
        String? idToken;
        if (!kIsWeb) {
          try {
            final future = GoogleSignIn.instance.attemptLightweightAuthentication();
            if (future != null) {
              final account = await future;
              idToken = account?.authentication.idToken;
            }
          } catch (_) {}
        }
        // Web またはサイレント認証不可の場合は Firebase ID token にフォールバック
        idToken ??= await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null) jwt = await authRepo.authenticate(idToken);
      }
      if (jwt == null) {
        if (mounted) setState(() { _loading = false; _error = 'Googleサインインが必要です'; });
        return;
      }

      final result = await apiClient.getGeminiUsage(jwt);
      if (!mounted) return;
      setState(() { _usage = result; _loading = false; });
      ref.read(nzwJpAiUsageProvider.notifier).state =
          (remaining: result.remaining, limit: result.limit, resetDate: result.resetDate);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _fmtResetDate(String? iso) {
    if (iso == null) return '—';
    return iso.replaceAll('-', '/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '利用状況を取得できませんでした',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: _fetch,
              tooltip: '再読み込み',
            ),
          ],
        ),
      );
    }

    final usage = _usage;
    if (usage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '月間利用回数',
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '${usage.used} / ${usage.limit} 回（リセット: ${_fmtResetDate(usage.resetDate)}）',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: _fetch,
            tooltip: '再読み込み',
          ),
        ],
      ),
    );
  }
}


