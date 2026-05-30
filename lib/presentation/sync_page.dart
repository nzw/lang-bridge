import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_config.dart';
import '../di/providers.dart';
import '../domain/dictionary_entry.dart';
import '../domain/import_validation_error.dart';
import '../domain/saved_sync_url.dart';
import 'saved_urls_page.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/column_mapping_dialog.dart';

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

enum _ImportStrategy {
  auto,     // 自動: 標準ヘッダーを自動判定、不明なときのみダイアログ表示
  bulk,     // 一括: 最初のシートで設定し、全シートに同じマッピングを適用
  perSheet, // シートごと: 毎回ダイアログで確認（自動判定で初期値を補完）
}

enum _ImportConflictMode {
  overwrite, // 上書き: 既存エントリを最新データで上書き
  addOnly,   // 新規追加のみ: ソース言語が既存と重複する行はスキップ
}

class _SyncPageState extends ConsumerState<SyncPage> {
  static const _kAllSheets = '（全シート）';

  String _status = '未同期';
  String _importStatus = '';
  String? _exportedUrl;
  final _importUrlController = TextEditingController();
  final _exportUrlController = TextEditingController();
  final _importUrlFocusNode = FocusNode();
  final _exportUrlFocusNode = FocusNode();
  late final _newSheetNameController = TextEditingController(
    text: () {
      final now = DateTime.now();
      return '${now.year.toString().substring(2)}/'
          '${now.month.toString().padLeft(2, '0')}/'
          '${now.day.toString().padLeft(2, '0')}';
    }(),
  );
  late final _newSpreadsheetTitleController = TextEditingController(
    text: () {
      final now = DateTime.now();
      final d = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      return 'LangBridge Export $d';
    }(),
  );
  String? _selectedSheet;
  List<String> _sheetNames = const [];
  List<List<String>> _previewRows = const [];
  bool _loadingSheets = false;
  bool _loadingPreview = false;
  bool _importing = false;
  String? _currentImportingSheet; // 取込中のシート名（進捗表示用）
  int _currentImportingIndex = 0;
  int _totalImportingSheets = 0;
  bool _creatingExport = false;
  ExportMode _exportMode = ExportMode.addSheetToExisting;
  _ImportStrategy _importStrategy = _ImportStrategy.auto;
  _ImportConflictMode _importConflictMode = _ImportConflictMode.overwrite;
  bool _importPanelExpanded = false;
  bool _exportPanelExpanded = false;
  String? _importBannerText;
  bool _importBannerIsError = false;
  bool _importBannerIsAuthError = false;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _importUrlFocusNode.addListener(_onImportUrlFocusChange);
    _exportUrlFocusNode.addListener(_onExportUrlFocusChange);
  }

  void _onImportUrlFocusChange() {
    if (!_importUrlFocusNode.hasFocus) {
      _autoSaveUrl(_importUrlController.text.trim());
    }
  }

  void _onExportUrlFocusChange() {
    if (!_exportUrlFocusNode.hasFocus) {
      _autoSaveUrl(_exportUrlController.text.trim());
    }
  }

  void _autoSaveUrl(String url) {
    if (!_isValidGoogleSheetsUrl(url)) return;
    final existing = ref.read(savedUrlsProvider).where((e) => e.url == url).firstOrNull;
    if (existing != null) return; // すでに保存済み
    ref.read(savedUrlsProvider.notifier).upsertByUrl(url, '（タイトル未取得）');
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showUrlPickerSheet(TextEditingController controller) {
    final savedUrls = ref.read(savedUrlsProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '保存済みスプレッドシート',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('URL管理'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const SavedUrlsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (savedUrls.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '保存済みURLがありません\n「URL管理」から追加できます',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: savedUrls.length,
                    separatorBuilder: (context, i) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final entry = savedUrls[index];
                      return ListTile(
                        title: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (entry.lastImportedAt != null)
                              Text(
                                'インポート: ${_formatDate(entry.lastImportedAt!)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          controller.text = entry.url;
                          Navigator.pop(ctx);
                          if (controller == _importUrlController) {
                            _setStateIfMounted(() {
                              _sheetNames = const [];
                              _selectedSheet = null;
                              _previewRows = const [];
                            });
                          } else {
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUrlField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required String currentUrl,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        errorText: currentUrl.isNotEmpty && !_isValidGoogleSheetsUrl(currentUrl)
            ? 'Google スプレッドシートの URL 形式で入力してください'
            : null,
        errorMaxLines: 3,
        suffixIconConstraints: const BoxConstraints(minHeight: 48),
        suffixIcon: SizedBox(
          width: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (currentUrl.isNotEmpty)
                IconButton(
                  tooltip: 'クリア',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    if (controller == _importUrlController) {
                      _setStateIfMounted(() {
                        _sheetNames = const [];
                        _selectedSheet = null;
                        _previewRows = const [];
                      });
                    } else {
                      setState(() {});
                    }
                  },
                )
              else
                IconButton(
                  tooltip: '貼り付け',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.content_paste, size: 20),
                  onPressed: () => _pasteToController(controller),
                ),
              IconButton(
                tooltip: '保存済みURLから選択',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_drop_down, size: 24),
                onPressed: () => _showUrlPickerSheet(controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

  void _clearImportBanner() {
    _setStateIfMounted(() {
      _importBannerText = null;
      _importBannerIsAuthError = false;
    });
  }

  void _setImportBanner(String text, {required bool isError, bool isAuthError = false}) {
    _setStateIfMounted(() {
      _importBannerText = text;
      _importBannerIsError = isError;
      _importBannerIsAuthError = isAuthError;
    });
  }

  Future<void> _signInFromBanner() async {
    _setStateIfMounted(() => _signingIn = true);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ログインに失敗しました\nGoogle Sign-In エラー: ${e.code.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ログインに失敗しました\n${e.code}: ${e.message ?? ""}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ログインに失敗しました\n$e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      _setStateIfMounted(() => _signingIn = false);
    }
  }

  Future<void> _notifyImportProblem({
    required String banner,
    required String snackbar,
    String? detailForDialog,
    bool isAuthError = false,
  }) async {
    _setImportBanner(banner, isError: true, isAuthError: isAuthError);
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(snackbar),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    if (detailForDialog != null &&
        detailForDialog.isNotEmpty &&
        mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('エラー詳細'),
          content: SingleChildScrollView(
            child: SelectableText(detailForDialog),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  Widget _importResultBanner(ThemeData theme) {
    if (_importBannerText == null) {
      return const SizedBox.shrink();
    }
    final err = _importBannerIsError;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: err
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                err ? Icons.error_outline : Icons.warning_amber_rounded,
                color: err
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _importBannerText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: err
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onSecondaryContainer,
                        height: 1.35,
                      ),
                    ),
                    if (_importBannerIsAuthError && AppConfig.useRealSheets) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _signingIn ? null : _signInFromBanner,
                        icon: _signingIn
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login, size: 18),
                        label: const Text('Googleでサインイン'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ローディング表示が 1 フレームも描画されないのを防ぐ。
  Future<void> _waitForLoadingUiFrame() async {
    await Future<void>.delayed(Duration.zero);
    // 1 フレーム待機（endOfFrame は一部環境で不安定なため遅延で代替）
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }

  /// 高速完了時でもインジケータが一瞬で消えないよう最低表示時間を確保する。
  Future<void> _ensureMinimumLoadingDuration(Stopwatch started, int millis) async {
    final rem = Duration(milliseconds: millis) - started.elapsed;
    if (rem > Duration.zero) {
      await Future<void>.delayed(rem);
    }
  }

  Future<bool> _ensureAuthenticated() async {
    if (!AppConfig.useRealSheets) {
      return true;
    }
    // Firebase Auth はセッションを自動復元する。currentUser が非 null なら認証済み。
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }
    await _signInFromBanner();
    return FirebaseAuth.instance.currentUser != null;
  }

  @override
  void dispose() {
    _importUrlFocusNode.removeListener(_onImportUrlFocusChange);
    _exportUrlFocusNode.removeListener(_onExportUrlFocusChange);
    _importUrlFocusNode.dispose();
    _exportUrlFocusNode.dispose();
    _importUrlController.dispose();
    _exportUrlController.dispose();
    _newSheetNameController.dispose();
    _newSpreadsheetTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadSheetsFromUrl() async {
    final url = _importUrlController.text.trim();
    if (!_isValidGoogleSheetsUrl(url)) {
      _setStateIfMounted(() => _importStatus = 'URL が無効です');
      await _notifyImportProblem(
        banner:
            'Google スプレッドシートの URL 形式ではありません（docs.google.com /spreadsheets/d/…）。',
        snackbar: '正しい URL を貼り付けてから「シート一覧取得」を押してください。',
        detailForDialog:
            'ブラウザで開いているスプレッドシートのアドレスバーから、そのままコピーしてください。\n\n入力例:\nhttps://docs.google.com/spreadsheets/d/（スプレッドシートID）/edit',
      );
      return;
    }
    // 認証チェック（サインインが必要な場合はここでダイアログを表示）
    _clearImportBanner();
    if (!await _ensureAuthenticated()) {
      return; // キャンセルまたは失敗 — ダイアログで案内済みのためエラー表示不要
    }
    final loadingWatch = Stopwatch()..start();
    _setStateIfMounted(() {
      _importStatus = '';
      _loadingSheets = true;
      _importPanelExpanded = true; // 折りたたみ中だと中のインジケータが見えない
      _sheetNames = const [];
      _selectedSheet = null;
      _previewRows = const [];
    });
    await _waitForLoadingUiFrame();
    try {
      final result = await ref.read(syncRepositoryProvider).listSheetNames(url);
      // 取得成功時に自動保存（実際のスプレッドシートタイトルで upsert）
      final sheetTitle = result.title?.isNotEmpty == true ? result.title! : 'スプレッドシート';
      await ref.read(savedUrlsProvider.notifier).upsertByUrl(url, sheetTitle);
      if (result.sheetNames.isEmpty) {
        _setStateIfMounted(() {
          _sheetNames = const [];
          _selectedSheet = null;
          _importStatus = 'シートが見つかりませんでした';
        });
        _setImportBanner(
          'このブックからシート名を取得できませんでした。共有設定（閲覧権限）と URL を確認してください。',
          isError: false,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('シート一覧が空です。共有範囲を確認してください。'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _setStateIfMounted(() {
          _sheetNames = result.sheetNames;
          _selectedSheet = _kAllSheets;
          _importStatus = 'シート一覧を取得しました';
        });
        _clearImportBanner();
      }
    } catch (e) {
      _setStateIfMounted(() => _importStatus = 'シート一覧取得失敗');
      if (e is UnsupportedError) {
        await _notifyImportProblem(
          banner: 'このファイルはGoogle スプレッドシート形式ではありません。',
          snackbar: 'Google スプレッドシートに変換してから共有URLを使用してください。詳細はダイアログを参照。',
          detailForDialog: e.message ?? e.toString(),
        );
      } else {
        await _notifyImportProblem(
          banner: 'シート一覧を取得できませんでした。',
          snackbar:
              'ログイン・ネットワーク・スプレッドシートの共有設定を確認してください。詳細はダイアログを参照。',
          detailForDialog: e.toString(),
        );
      }
    } finally {
      await _ensureMinimumLoadingDuration(loadingWatch, 450);
      _setStateIfMounted(() => _loadingSheets = false);
    }
  }

  Future<void> _previewImport() async {
    if (!await _ensureAuthenticated()) {
      return;
    }
    final url = _importUrlController.text.trim();
    final sheet = _selectedSheet;
    if (!_isValidGoogleSheetsUrl(url) || sheet == null) {
      _setStateIfMounted(() => _importStatus = 'URL またはシートが不足しています');
      await _notifyImportProblem(
        banner: '有効なスプレッドシート URL と、取得済みのシートを選んでください。',
        snackbar: '先に「シート一覧取得」でシートを表示してからプレビューしてください。',
      );
      return;
    }
    _clearImportBanner();
    _setStateIfMounted(() {
      _importStatus = '';
      _loadingPreview = true;
    });
    // 全シートの場合は先頭シートのみプレビュー
    final previewSheet = sheet == _kAllSheets ? _sheetNames.first : sheet;
    try {
      final rows = await ref
          .read(syncRepositoryProvider)
          .importRowsFromSheet(spreadsheetUrlOrId: url, sheetName: previewSheet);
      if (rows.isEmpty) {
        _setStateIfMounted(() {
          _previewRows = const [];
          _importStatus = 'データが空です';
        });
        _setImportBanner(
          'シート上にデータがありません（または読み取れません）。',
          isError: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('プレビュー対象が空です'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      bool hasValidFormat = true;
      try {
        ref.read(validateImportFormatUseCaseProvider).execute(rows.first);
      } on ImportValidationError {
        hasValidFormat = false;
      }
      _setStateIfMounted(() {
        _previewRows = rows.take(20).toList();
        _importStatus = sheet == _kAllSheets
            ? 'プレビュー取得完了（先頭シートのみ表示）'
            : 'プレビュー取得完了（先頭20行）';
      });
      if (!hasValidFormat) {
        _setImportBanner(
          '標準ヘッダーが見つかりません。インポート時に列マッピングダイアログが表示されます。',
          isError: false,
        );
      } else if (sheet == _kAllSheets) {
        _setImportBanner('「全シート」選択時は先頭シートのみプレビュー表示します。', isError: false);
      } else {
        _clearImportBanner();
      }
    } catch (e) {
      _setStateIfMounted(() => _importStatus = 'プレビュー取得失敗');
      await _notifyImportProblem(
        banner: 'プレビュー用データを取得できませんでした。',
        snackbar: '権限・ネットワーク・シート名を確認してください。',
        detailForDialog: e.toString(),
      );
    } finally {
      _setStateIfMounted(() => _loadingPreview = false);
    }
  }

  Future<void> _confirmImport() async {
    if (!await _ensureAuthenticated()) {
      return;
    }
    final url = _importUrlController.text.trim();
    final sheet = _selectedSheet;
    if (!_isValidGoogleSheetsUrl(url) || sheet == null) {
      _setStateIfMounted(() => _importStatus = 'URL またはシートが不足しています');
      await _notifyImportProblem(
        banner: '有効な URL とシートを指定してください。',
        snackbar: 'シート一覧取得とシート選択を済ませてからインポートしてください。',
      );
      return;
    }
    _clearImportBanner();
    _setStateIfMounted(() {
      _importStatus = '';
      _importing = true;
      _currentImportingSheet = null;
      _currentImportingIndex = 0;
      _totalImportingSheets = 0;
    });

    final sheetsToImport = sheet == _kAllSheets
        ? List<String>.from(_sheetNames)
        : [sheet];
    final isMultiSheet = sheetsToImport.length > 1;
    // インポートボタンを押した1回の操作を識別するID
    final importSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final syncRepo = ref.read(syncRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);
    var totalNew = 0;
    var totalUpdated = 0;
    final skippedSheets = <String>[];

    // 全シートを処理してから1回だけディスク書き込みする（シートごとに書くと
    // jsonEncode が N 回走りメインスレッドをブロックする原因になる）。
    final allSheetEntries = <String, DictionaryEntry>{};
    final allStaleIds = <String>{};
    // ループ前に既存データを一度だけ読み込む
    final List<DictionaryEntry> existingAll;
    try {
      existingAll = await userRepo.listAll();
    } catch (e) {
      _setStateIfMounted(() {
        _importing = false;
        _importStatus = 'データ読み込みに失敗しました';
      });
      _setImportBanner('データ読み込みに失敗しました: $e', isError: true);
      return;
    }
    final existingMap = {for (final e in existingAll) e.id: e};
    // addOnly モード用: インポート中に追加した lang1 も随時追跡する
    final runningLang1Set = _importConflictMode == _ImportConflictMode.addOnly
        ? existingAll.map((e) => e.lang1).toSet()
        : <String>{};

    // 一括モード: 最初のシートのヘッダーでダイアログを一度だけ表示し、全シートに適用する
    ColumnMappingResult? bulkMapping;
    if (_importStrategy == _ImportStrategy.bulk && isMultiSheet) {
      _setStateIfMounted(() => _importStatus = '列マッピングを設定中…');
      List<List<String>> firstRows;
      try {
        firstRows = await syncRepo.importRowsFromSheet(
          spreadsheetUrlOrId: url,
          sheetName: sheetsToImport.first,
        );
      } catch (e) {
        await _notifyImportProblem(
          banner: '「${sheetsToImport.first}」の取得に失敗しました。',
          snackbar: e.toString(),
        );
        _setStateIfMounted(() => _importing = false);
        return;
      }
      if (!mounted) return;
      final bulkDialogResult = await showColumnMappingDialog(
        context: context,
        headers: firstRows.isNotEmpty ? firstRows.first : [],
        unknownHeaders: firstRows.isNotEmpty ? firstRows.first : [],
        sheetName: sheetsToImport.first,
        totalSheets: sheetsToImport.length,
        isBulk: true,
      );
      if (bulkDialogResult is! ColumnMappingConfirm) {
        _setStateIfMounted(() {
          _importing = false;
          _importStatus = 'インポートを中止しました';
        });
        return;
      }
      bulkMapping = bulkDialogResult.mapping;
      if (!mounted) return;
    }

    try {
      _setStateIfMounted(() => _totalImportingSheets = sheetsToImport.length);
      for (var si = 0; si < sheetsToImport.length; si++) {
        final sheetName = sheetsToImport[si];
        _setStateIfMounted(() {
          _currentImportingSheet = sheetName;
          _currentImportingIndex = si + 1;
          _importStatus = '「$sheetName」を取得中… (${si + 1}/${sheetsToImport.length})';
        });

        // --- シートごとに行取得（一括モードは先頭シート分を再利用しない — 全シートfetch） ---
        List<List<String>> rows;
        try {
          rows = await syncRepo.importRowsFromSheet(
            spreadsheetUrlOrId: url,
            sheetName: sheetName,
          );
        } catch (e) {
          await _notifyImportProblem(
            banner: '「$sheetName」の取得に失敗しました。',
            snackbar: e.toString(),
          );
          skippedSheets.add(sheetName);
          continue;
        }

        if (rows.length < 2) {
          skippedSheets.add(sheetName);
          continue; // データ行なし（ヘッダーのみ or 空）
        }

        // --- フォーマット解決 ---
        List<int> lang1Indexes;
        List<int> lang2Indexes;
        List<int> memoIndexes;
        List<int> categoryIndexes;

        if (_importStrategy == _ImportStrategy.bulk && bulkMapping != null) {
          // 一括モード: 共通マッピングをそのまま適用
          lang1Indexes = bulkMapping.lang1Indexes;
          lang2Indexes = bulkMapping.lang2Indexes;
          memoIndexes = bulkMapping.memoIndexes;
          categoryIndexes = bulkMapping.categoryIndexes;
        } else if (_importStrategy == _ImportStrategy.perSheet) {
          // シートごとモード: 常にダイアログ表示（自動判定で初期値を補完）
          if (!mounted) return;
          _setStateIfMounted(() => _importStatus =
              '「$sheetName」の列設定中… (${si + 1}/${sheetsToImport.length})');
          final perSheetResult = await showColumnMappingDialog(
            context: context,
            headers: rows.first,
            unknownHeaders: rows.first,
            sheetName: isMultiSheet ? sheetName : null,
            sheetIndex: isMultiSheet ? si + 1 : null,
            totalSheets: isMultiSheet ? sheetsToImport.length : null,
          );
          if (perSheetResult is ColumnMappingSkip) {
            skippedSheets.add(sheetName);
            continue;
          }
          if (perSheetResult is ColumnMappingAbort) {
            _setStateIfMounted(() => _importStatus = 'インポートを中止しました');
            return;
          }
          if (!mounted) return;
          final perSheetMapping = (perSheetResult as ColumnMappingConfirm).mapping;
          lang1Indexes = perSheetMapping.lang1Indexes;
          lang2Indexes = perSheetMapping.lang2Indexes;
          memoIndexes = perSheetMapping.memoIndexes;
          categoryIndexes = perSheetMapping.categoryIndexes;
        } else {
          // 自動モード: 標準ヘッダーを判定、失敗時のみダイアログ
          try {
            final format = ref
                .read(validateImportFormatUseCaseProvider)
                .execute(rows.first);
            lang1Indexes = [format.lang1Index];
            lang2Indexes = [format.lang2Index];
            memoIndexes = format.memoIndex != null ? [format.memoIndex!] : [];
            categoryIndexes = format.categoryIndexes;
          } on ImportValidationError catch (e) {
            if (!mounted) return;
            final autoResult = await showColumnMappingDialog(
              context: context,
              headers: rows.first,
              unknownHeaders: e.unknownHeaders,
              sheetName: isMultiSheet ? sheetName : null,
              sheetIndex: isMultiSheet ? si + 1 : null,
              totalSheets: isMultiSheet ? sheetsToImport.length : null,
            );
            if (autoResult is ColumnMappingSkip) {
              skippedSheets.add(sheetName);
              continue;
            }
            if (autoResult is ColumnMappingAbort) {
              _setStateIfMounted(() => _importStatus = 'インポートを中止しました');
              return;
            }
            if (!mounted) return;
            final autoMapping = (autoResult as ColumnMappingConfirm).mapping;
            lang1Indexes = autoMapping.lang1Indexes;
            lang2Indexes = autoMapping.lang2Indexes;
            memoIndexes = autoMapping.memoIndexes;
            categoryIndexes = autoMapping.categoryIndexes;
          }
        }

        // --- エントリを組み立てて allSheetEntries に蓄積（ディスク書込みはループ後1回） ---
        final headers = rows.first;
        final now = DateTime.now();

        final sheetEntries = <DictionaryEntry>[];
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          final lang1 = lang1Indexes
              .map((idx) => _valueAt(row, idx))
              .where((v) => v.isNotEmpty)
              .join(' ');
          final lang2 = lang2Indexes
              .map((idx) => _valueAt(row, idx))
              .where((v) => v.isNotEmpty)
              .join(' ');
          if (lang1.isEmpty || lang2.isEmpty) continue;

          // 新規追加のみモード: lang1 が既存 or 今回追加済みと重複する行はスキップ
          if (_importConflictMode == _ImportConflictMode.addOnly &&
              runningLang1Set.contains(lang1)) {
            continue;
          }

          final memoParts = memoIndexes.map((idx) {
            final v = _valueAt(row, idx);
            if (v.isEmpty) return '';
            final colName = idx < headers.length ? headers[idx] : '';
            return colName.isNotEmpty ? '$colName: $v' : v;
          }).where((s) => s.isNotEmpty).toList();
          final memo = memoParts.join('\n');

          final columnCategories = categoryIndexes
              .map((idx) => _valueAt(row, idx))
              .where((e) => e.isNotEmpty)
              .toList();
          final categories = [
            sheetName,
            ...columnCategories.where((c) => c != sheetName),
          ];

          final id = 'sheet2-${_spreadsheetIdFrom(url)}-$sheetName-$i';
          sheetEntries.add(DictionaryEntry(
            id: id,
            lang1: lang1,
            lang2: lang2,
            memo: memo,
            categories: categories,
            sourceType: EntrySourceType.userSheet,
            sourceUrl: url,
            importSessionId: existingMap[id]?.importSessionId ?? importSessionId,
            createdAt: existingMap[id]?.createdAt ?? now,
            updatedAt: now,
          ));
        }

        // 蓄積（同一ID は後勝ち）
        for (final e in sheetEntries) {
          allSheetEntries[e.id] = e;
          if (_importConflictMode == _ImportConflictMode.addOnly) {
            runningLang1Set.add(e.lang1);
          }
        }
        final sheetNew = sheetEntries.where((e) => !existingMap.containsKey(e.id)).length;
        totalNew += sheetNew;
        totalUpdated += sheetEntries.length - sheetNew;

        // 上書きモード: 旧IDのスタールエントリを収集（削除もループ後1回）
        if (_importConflictMode == _ImportConflictMode.overwrite) {
          final ssId = _spreadsheetIdFrom(url);
          final sheetNewIds = sheetEntries.map((e) => e.id).toSet();
          final staleInSheet = existingAll
              .where((e) =>
                  e.sourceType == EntrySourceType.userSheet &&
                  _spreadsheetIdFrom(e.sourceUrl ?? '') == ssId &&
                  e.categories.isNotEmpty &&
                  e.categories.first == sheetName &&
                  !sheetNewIds.contains(e.id))
              .map((e) => e.id);
          allStaleIds.addAll(staleInSheet);
        }
      }

      // ディスク書込みをここで1回だけ実行（N シート分をまとめて jsonEncode → setString）
      await userRepo.upsertMany(allSheetEntries.values.toList());
      final cleanStaleIds = allStaleIds
          .where((id) => !allSheetEntries.containsKey(id))
          .toList();
      if (cleanStaleIds.isNotEmpty) {
        await userRepo.deleteManyByIds(cleanStaleIds);
      }

      // --- 完了通知 ---
      if (!mounted) return;
      final totalImported = totalNew + totalUpdated;
      final skippedMsg = skippedSheets.isEmpty
          ? ''
          : '（スキップ: ${skippedSheets.join(', ')}）';
      _clearImportBanner();
      if (totalImported == 0) {
        if (_importConflictMode == _ImportConflictMode.addOnly) {
          // 新規追加のみモードで追加対象がないのは正常（エラーではない）
          final msg = '追加対象なし（全件が既存データと重複）$skippedMsg';
          _setStateIfMounted(() => _importStatus = msg);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        } else {
          _setStateIfMounted(() => _importStatus = '取り込める行が見つかりませんでした$skippedMsg');
          await _notifyImportProblem(
            banner: '取り込める行が見つかりませんでした。$skippedMsg',
            snackbar: '列の割り当てとシートの内容を確認してください。',
          );
        }
      } else {
        final String countMsg;
        final completedAt = _formatDate(DateTime.now());
        if (_importConflictMode == _ImportConflictMode.overwrite) {
          if (totalNew > 0 && totalUpdated > 0) {
            countMsg = '新規 $totalNew 件・上書き $totalUpdated 件';
          } else if (totalUpdated > 0) {
            countMsg = '$totalUpdated 件を上書き';
          } else {
            countMsg = '新規 $totalNew 件';
          }
        } else {
          countMsg = '新規 $totalNew 件を追加';
        }
        _setStateIfMounted(() => _importStatus = '完了: $countMsg（$completedAt）$skippedMsg');
        ref.read(savedUrlsProvider.notifier).updateLastImportedAt(url);
        ScaffoldMessenger.of(context).clearSnackBars();
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('取込完了'),
              content: Text('$countMsg（$completedAt）$skippedMsg'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('閉じる'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('ホームに戻る'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      _setStateIfMounted(() => _importStatus = 'インポート失敗');
      await _notifyImportProblem(
        banner: 'インポート中にエラーが発生しました。',
        snackbar: '通信・権限・シート内容を確認してください。',
        detailForDialog: e.toString(),
      );
    } finally {
      _setStateIfMounted(() {
        _importing = false;
        _currentImportingSheet = null;
      });
    }
  }

  Future<void> _exportWithMode() async {
    // 認証チェック（サインインが必要な場合はここでダイアログを表示）
    if (!await _ensureAuthenticated()) {
      return;
    }
    _setStateIfMounted(() => _creatingExport = true);
    await _waitForLoadingUiFrame();
    try {
      final entries = await ref.read(userRepositoryProvider).listAll();
      final rows = <List<String>>[
        ['ソース言語', 'ターゲット言語', 'メモ', 'カテゴリ'],
        ...entries.map(
          (e) => [e.lang1, e.lang2, e.memo, e.categories.join('//')],
        ),
      ];
      final syncRepo = ref.read(syncRepositoryProvider);
      late final String resultUrl;
      if (_exportMode == ExportMode.addSheetToExisting) {
        final target = _exportUrlController.text.trim();
        if (!_isValidGoogleSheetsUrl(target)) {
          _setStateIfMounted(() => _status = '有効なエクスポート先URLを入力してください');
          return;
        }
        resultUrl = await syncRepo.exportRowsToNewSheet(
          spreadsheetUrlOrId: target,
          newSheetName: _newSheetNameController.text.trim().isEmpty
              ? 'Sheet'
              : _newSheetNameController.text.trim(),
          rows: rows,
        );
      } else {
        resultUrl = await syncRepo.exportRowsToNewSpreadsheet(
          title: _newSpreadsheetTitleController.text.trim().isEmpty
              ? 'LangBridge Export'
              : _newSpreadsheetTitleController.text.trim(),
          initialSheetName: 'Sheet1',
          rows: rows,
        );
      }
      _setStateIfMounted(() {
        _status = 'エクスポート完了';
        _exportedUrl = resultUrl;
      });
      // エクスポート先URLが保存済みの場合、最終エクスポート日時を記録
      if (_exportMode == ExportMode.addSheetToExisting) {
        ref.read(savedUrlsProvider.notifier).updateLastExportedAt(
          _exportUrlController.text.trim(),
        );
      }
    } catch (e) {
      _setStateIfMounted(() => _status = 'エクスポート失敗: $e');
    } finally {
      _setStateIfMounted(() => _creatingExport = false);
    }
  }

  Future<void> _pasteToController(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _setStateIfMounted(() => _status = '貼り付け失敗: クリップボードにテキストがありません');
      return;
    }

    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
    _setStateIfMounted(() => _status = 'URLを貼り付けました');
  }

  bool _isValidGoogleSheetsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return false;
    }
    if (!uri.host.contains('docs.google.com')) {
      return false;
    }
    final path = uri.path;
    return path.contains('/spreadsheets/d/');
  }

  /// URL から Google Sheets のスプレッドシートIDを抽出する。
  /// 抽出できない場合は URL 全体を返す（比較用の最終手段）。
  static String _spreadsheetIdFrom(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url;
    final segments = uri.pathSegments;
    final dIdx = segments.indexOf('d');
    if (dIdx >= 0 && dIdx + 1 < segments.length) {
      return segments[dIdx + 1];
    }
    return url;
  }

  String _valueAt(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  Widget _buildAutoSyncOverview(ThemeData theme) {
    final savedUrls = ref.watch(savedUrlsProvider);
    final cs = theme.colorScheme;

    String fmtDt(DateTime? dt) {
      if (dt == null) return '—';
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    String fmtDate(DateTime? dt) {
      if (dt == null) return '—';
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sync, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text('自動同期',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('管理'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SavedUrlsPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (savedUrls.isEmpty)
          _autoSyncEmptyCard(theme)
        else
          ...savedUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: url.isAutoSyncEnabled
                          ? cs.primary.withValues(alpha: 0.4)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // タイトル行
                        Row(children: [
                          Icon(
                            url.isAutoSyncEnabled
                                ? Icons.sync
                                : Icons.sync_disabled,
                            size: 16,
                            color: url.isAutoSyncEnabled
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(url.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          // 停止/再開トグル
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: url.isAutoSyncEnabled,
                              onChanged: (on) {
                                ref
                                    .read(savedUrlsProvider.notifier)
                                    .updateAutoSyncSettings(
                                      url.id,
                                      schedule: on
                                          ? AutoSyncSchedule.daily
                                          : AutoSyncSchedule.none,
                                      mode: url.autoSyncMode,
                                      sheetName: url.autoSyncSheetName,
                                    );
                              },
                            ),
                          ),
                        ]),
                        // 設定・状態行
                        if (url.isAutoSyncEnabled) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            SizedBox(
                              width: 80,
                              child: _autoSyncSelect<AutoSyncSchedule>(
                                theme: theme,
                                icon: Icons.schedule,
                                value: url.autoSyncSchedule ==
                                        AutoSyncSchedule.none
                                    ? AutoSyncSchedule.daily
                                    : url.autoSyncSchedule,
                                items: const [
                                  (AutoSyncSchedule.daily, '毎日'),
                                  (AutoSyncSchedule.weekly, '毎週'),
                                ],
                                onChanged: (s) => ref
                                    .read(savedUrlsProvider.notifier)
                                    .updateAutoSyncSettings(url.id,
                                        schedule: s,
                                        mode: url.autoSyncMode,
                                        sheetName: url.autoSyncSheetName),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 116,
                              child: _autoSyncSelect<AutoSyncMode>(
                                theme: theme,
                                icon: Icons.tune,
                                value: url.autoSyncMode,
                                items: const [
                                  (AutoSyncMode.addOnly, '追加のみ'),
                                  (AutoSyncMode.forceApply, '強制反映'),
                                  (AutoSyncMode.mergeConfirm, 'マージ確認'),
                                ],
                                onChanged: (m) => ref
                                    .read(savedUrlsProvider.notifier)
                                    .updateAutoSyncSettings(url.id,
                                        schedule: url.autoSyncSchedule,
                                        mode: m,
                                        sheetName: url.autoSyncSheetName),
                              ),
                            ),
                            if (url.autoSyncSheetName != null) ...[
                              const SizedBox(width: 8),
                              _chip(theme,
                                  icon: Icons.table_chart_outlined,
                                  label: url.autoSyncSheetName!),
                            ],
                          ]),
                          const SizedBox(height: 6),
                          DefaultTextStyle(
                            style: theme.textTheme.bodySmall!
                                .copyWith(color: cs.onSurfaceVariant),
                            child: Row(children: [
                              const Icon(Icons.history, size: 13),
                              const SizedBox(width: 3),
                              Text('前回: ${fmtDt(url.lastAutoSyncAt)}'),
                              const SizedBox(width: 12),
                              if (url.nextAutoSyncAt != null) ...[
                                Icon(Icons.arrow_forward, size: 13,
                                    color: cs.primary),
                                const SizedBox(width: 3),
                                Text(
                                  '次回: ${fmtDate(url.nextAutoSyncAt)} 0:00',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: cs.primary),
                                ),
                              ],
                            ]),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('停止中',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                ),
              )),
        if (savedUrls.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('URLを追加'),
              style:
                  TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedUrlsPage()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _autoSyncEmptyCard(ThemeData theme) {
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SavedUrlsPage()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
          color: cs.surfaceContainerLowest,
        ),
        child: Column(children: [
          Icon(Icons.sync_outlined,
              size: 32, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('自動同期が設定されていません',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('タップしてスプレッドシートURLを登録',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.primary)),
        ]),
      ),
    );
  }

  Widget _chip(ThemeData theme,
      {required IconData icon, required String label}) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: cs.onSecondaryContainer),
        const SizedBox(width: 3),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSecondaryContainer)),
      ]),
    );
  }

  Widget _autoSyncSelect<T>({
    required ThemeData theme,
    required IconData icon,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    final cs = theme.colorScheme;
    final label = items.firstWhere((e) => e.$1 == value).$2;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => items
          .map((e) => PopupMenuItem<T>(value: e.$1, child: Text(e.$2)))
          .toList(),
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(icon, size: 12, color: cs.onPrimaryContainer),
          const SizedBox(width: 4),
          Expanded(
            child: Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onPrimaryContainer),
                overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.arrow_drop_down, size: 14, color: cs.onPrimaryContainer),
        ]),
      ),
    );
  }

  Widget _buildConflictModeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('重複時の処理', style: theme.textTheme.labelMedium),
        ),
        SegmentedButton<_ImportConflictMode>(
          segments: const [
            ButtonSegment(
              value: _ImportConflictMode.overwrite,
              label: Text('上書き'),
            ),
            ButtonSegment(
              value: _ImportConflictMode.addOnly,
              label: Text('新規追加のみ'),
            ),
          ],
          selected: {_importConflictMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              setState(() => _importConflictMode = s.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            switch (_importConflictMode) {
              _ImportConflictMode.overwrite =>
                '既存の単語データを最新データで上書きします。',
              _ImportConflictMode.addOnly =>
                'ソース言語（A列）が既存データと重複する行はスキップし、新規分のみ追加します。',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrategySelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('取込方式', style: theme.textTheme.labelMedium),
        ),
        SegmentedButton<_ImportStrategy>(
          segments: const [
            ButtonSegment(
              value: _ImportStrategy.auto,
              label: Text('自動'),
            ),
            ButtonSegment(
              value: _ImportStrategy.bulk,
              label: Text('一括設定'),
            ),
            ButtonSegment(
              value: _ImportStrategy.perSheet,
              label: Text('シートごと'),
            ),
          ],
          selected: {_importStrategy},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _importStrategy = s.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            switch (_importStrategy) {
              _ImportStrategy.auto =>
                '標準ヘッダーを自動判定します。不明な列名の場合のみ確認ダイアログが表示されます。',
              _ImportStrategy.bulk =>
                '最初のシートで列の割り当てを設定し、全シートに同じ設定を適用します。',
              _ImportStrategy.perSheet =>
                'シートごとに列の割り当てを確認します。ヘッダーが異なるシートが混在する場合に使います。',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// ログイン周りの補足。ExpansionTile の既定パディングが広いので dense + 余白を抑える。
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
    final importUrl = _importUrlController.text.trim();
    final exportUrl = _exportUrlController.text.trim();
    final canLoadSheets = !_loadingSheets && _isValidGoogleSheetsUrl(importUrl);
    final canPreview =
        _selectedSheet != null &&
        !_loadingPreview &&
        _isValidGoogleSheetsUrl(importUrl);
    final canImport = _selectedSheet != null &&
        _isValidGoogleSheetsUrl(importUrl) &&
        !_importing;
    final canExport =
        !_creatingExport &&
        (_exportMode == ExportMode.newSpreadsheet ||
            _isValidGoogleSheetsUrl(exportUrl));

    final theme = Theme.of(context);
    final scaffoldBg = theme.colorScheme.surface;
    final appBarBg = theme.colorScheme.surface;
    final userInfo = ref.watch(currentUserInfoProvider);

    // ログイン直後: 残留していた認証エラーバナーをクリアしてユーザーに再操作を促す。
    ref.listen(firebaseUserProvider, (prev, next) {
      final wasSignedIn = prev?.valueOrNull != null;
      final isSignedIn = next.valueOrNull != null;
      if (!wasSignedIn && isSignedIn) {
        _clearImportBanner();
        _setStateIfMounted(() {
          _importStatus = '';
          _status = 'Googleログイン完了 — 再度「シート一覧取得」を押してください。';
        });
      } else if (wasSignedIn && !isSignedIn) {
        _setStateIfMounted(() => _status = 'サインアウトしました');
      }
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Google Sheets で同期'),
        actions: [
          const AccountMenuButton(showGoHome: true),
        ],
      ),
      body: ColoredBox(
        color: scaffoldBg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadingSheets &&
                  _isValidGoogleSheetsUrl(importUrl)) ...[
                Material(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        minHeight: 4,
                        color: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'シート一覧を取得しています（接続中）',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAutoSyncOverview(theme),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text('手動同期モード（Import/Export）',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    ExpansionPanelList(
              elevation: 1,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback: (index, expanded) {
                setState(() {
                  if (index == 0) {
                    _importPanelExpanded = expanded;
                  } else {
                    _exportPanelExpanded = expanded;
                  }
                });
              },
              children: [
                ExpansionPanel(
                  canTapOnHeader: true,
                  isExpanded: _importPanelExpanded,
                  headerBuilder: (context, isExpanded) {
                    return ListTile(
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: const Text('インポート'),
                      subtitle: Text(
                        isExpanded
                            ? 'スプレッドシートから単語を取り込みます'
                            : 'タップしてURL・シート・プレビューを設定',
                      ),
                    );
                  },
                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // URL 入力（クリア／貼り付け ＋ 保存済み選択）
                        _buildUrlField(
                          controller: _importUrlController,
                          focusNode: _importUrlFocusNode,
                          labelText: 'インポート元スプレッドシートURL',
                          currentUrl: importUrl,
                        ),
                        const SizedBox(height: 12),
                        // シート一覧取得
                        if (_loadingSheets && _isValidGoogleSheetsUrl(importUrl))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'シート一覧を取得中…',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else
                          FilledButton.icon(
                            onPressed: canLoadSheets ? _loadSheetsFromUrl : null,
                            icon: const Icon(Icons.table_rows_outlined, size: 20),
                            label: const Text('シート一覧取得'),
                          ),
                        // 取込対象シート選択（全シート含む）
                        if (_sheetNames.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          // --- 取込方式（全シート選択時のみ表示）---
                          if (_selectedSheet == _kAllSheets || _sheetNames.length > 1)
                            _buildStrategySelector(theme),
                          _buildConflictModeSelector(theme),
                          InputDecorator(
                            key: ValueKey<String>(_sheetNames.join('|')),
                            decoration: const InputDecoration(
                              labelText: '取込対象シート',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsetsDirectional.only(
                                start: 12,
                                end: 8,
                                top: 4,
                                bottom: 4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: ([_kAllSheets, ..._sheetNames]
                                        .contains(_selectedSheet))
                                    ? _selectedSheet
                                    : _kAllSheets,
                                items: [
                                  DropdownMenuItem<String>(
                                    value: _kAllSheets,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.select_all,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _kAllSheets,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._sheetNames.map(
                                    (name) => DropdownMenuItem<String>(
                                      value: name,
                                      child: Text(name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedSheet = value),
                              ),
                            ),
                          ),
                        ],
                        // エラー／情報バナー
                        if (_importBannerText != null) ...[
                          const SizedBox(height: 8),
                          _importResultBanner(theme),
                        ],
                        // プレビュー・インポートボタン（シート選択後に表示）
                        if (_sheetNames.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_selectedSheet != _kAllSheets)
                                OutlinedButton.icon(
                                  onPressed: canPreview ? _previewImport : null,
                                  icon: const Icon(Icons.preview_outlined, size: 18),
                                  label: const Text('プレビュー'),
                                ),
                              FilledButton.icon(
                                onPressed: canImport ? _confirmImport : null,
                                icon: _importing
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.download_outlined, size: 18),
                                label: Text(_importing ? '取込中...' : 'インポート'),
                              ),
                            ],
                          ),
                          // 取込中: シート進捗表示
                          if (_importing && _currentImportingSheet != null) ...[
                            const SizedBox(height: 10),
                            Material(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _totalImportingSheets > 1
                                            ? '「$_currentImportingSheet」を取込中'
                                                ' ($_currentImportingIndex / $_totalImportingSheets)'
                                            : '「$_currentImportingSheet」を取込中',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                        // インポート状態メッセージ
                        if (_importStatus.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _importStatus,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        // プレビューテーブル
                        if (_previewRows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            '取込プレビュー（先頭20行 / ${_selectedSheet ?? ""}）',
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 220,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: _previewRows.first
                                      .map(
                                        (header) => DataColumn(
                                          label: Text(
                                            header.isEmpty ? '(空)' : header,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  rows: _previewRows.skip(1).map((row) {
                                    return DataRow(
                                      cells: _previewRows.first
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final idx = entry.key;
                                            final value = idx < row.length
                                                ? row[idx]
                                                : '';
                                            return DataCell(Text(value));
                                          })
                                          .toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ExpansionPanel(
                  canTapOnHeader: true,
                  isExpanded: _exportPanelExpanded,
                  headerBuilder: (context, isExpanded) {
                    return ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: const Text('エクスポート'),
                      subtitle: Text(
                        isExpanded
                            ? '端末の単語をスプレッドシートに書き出します'
                            : 'タップして書き出し先・方式を設定',
                      ),
                    );
                  },
                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RadioGroup<ExportMode>(
                          groupValue: _exportMode,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _exportMode = value);
                          },
                          child: const Column(
                            children: [
                              RadioListTile<ExportMode>(
                                contentPadding: EdgeInsets.zero,
                                value: ExportMode.addSheetToExisting,
                                title: Text('既存URLに新規シート追加'),
                              ),
                              RadioListTile<ExportMode>(
                                contentPadding: EdgeInsets.zero,
                                value: ExportMode.newSpreadsheet,
                                title: Text('新規スプレッドシート作成'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_exportMode == ExportMode.addSheetToExisting) ...[
                          _buildUrlField(
                            controller: _exportUrlController,
                            focusNode: _exportUrlFocusNode,
                            labelText: 'エクスポート先スプレッドシートURL',
                            currentUrl: exportUrl,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newSheetNameController,
                            decoration: const InputDecoration(
                              labelText: '新規シート名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        if (_exportMode == ExportMode.newSpreadsheet) ...[
                          const Text('初期シート名は自動で Sheet1 になります'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newSpreadsheetTitleController,
                            decoration: const InputDecoration(
                              labelText: '新規スプレッドシート名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: canExport ? _exportWithMode : null,
                          icon: const Icon(Icons.upload),
                          label: const Text('エクスポート実行'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
                    ),
                    const SizedBox(height: 16),
                    Text('状態: $_status'),
                    if (_exportedUrl != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse(_exportedUrl!),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Text(
                                _exportedUrl!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: theme.colorScheme.primary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'URLをコピー',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _exportedUrl!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URLをコピーしました'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(height: 8),
                    if (!AppConfig.useRealSheets) ...[
                      Text(
                        'このビルドはクラウドに接続しません（検索は利用できます）。',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 6),
                      _loginDetailsExpansion(
                        theme: theme,
                        backgroundColor: scaffoldBg,
                        title: 'Q. このモードでできること・できないこと',
                        detailText:
                            'A. インポートに URL を入れても実データは取得できません。'
                            '${kDebugMode ? ' 開発時は `flutter run --dart-define=USE_REAL_SHEETS=false` と同じ挙動です。' : ''}',
                      ),
                    ] else ...[
                      Text(
                        userInfo == null
                            ? 'シートの取り込み・書き出しには、右上のアカウントアイコンから Google にサインインしてください。'
                            : 'ログイン中: ${userInfo.email}',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ExportMode { addSheetToExisting, newSpreadsheet }
