import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_config.dart';
import '../di/providers.dart';
import '../infrastructure/update/update_info.dart';
import '../domain/dict_link_settings.dart';
import '../domain/dictionary_entry.dart';
import '../domain/library_search_options.dart';
import '../domain/ai_history_entry.dart';
import 'search_history_page.dart';
import 'entry_detail_page.dart';
import 'widgets/ai_assist_sheet.dart';
import 'widgets/library_search_options_panel.dart';
import 'flashcard_page.dart';
import 'library_page.dart';
import 'navigation_icons.dart';
import 'widgets/account_menu_button.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  LibrarySearchOptions _searchOptions = const LibrarySearchOptions();
  bool _searchOptionsExpanded = false;

  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  final _historyMenuController = MenuController();

  List<DictionaryEntry> _allUserEntries = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      if (_focusNode.hasFocus) {
        setState(() {});
      } else {
        // オプションボタンのタップ（PointerDown でフォーカス喪失）と
        // 展開フラグ更新（PointerUp の onPressed）の間の race を防ぐため
        // フォーカス喪失時は次フレームで再ビルドする。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    });
    Future<void>.microtask(_loadSearchOptions);
    Future<void>.microtask(_initSpeech);
    Future<void>.microtask(_loadAllUserEntries);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && AppConfig.isApkBuild) {
      Future<void>.microtask(_checkForUpdate);
    }
  }

  Future<void> _checkForUpdate() async {
    final info = await ref.read(updateCheckerProvider).check();
    if (info == null || !info.isUpdateAvailable || !mounted) return;

    if (!info.isForceUpdate) {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getString('update_seen_version');
      if (seen == info.latestVersion) return;
      await prefs.setString('update_seen_version', info.latestVersion);
    }

    _showUpdateDialog(info);
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog<void>(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      builder: (ctx) => _UpdateDialog(info: info),
    );
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
        _onChanged(result.recognizedWords);
        if (result.finalResult) setState(() => _isListening = false);
      },
      localeId: 'ja-JP',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _loadSearchOptions() async {
    final o = await ref.read(librarySearchPrefsStoreProvider).load();
    if (mounted) setState(() => _searchOptions = o);
  }

  Future<void> _loadAllUserEntries() async {
    final entries = await ref.read(userRepositoryProvider).listAll();
    if (mounted) setState(() => _allUserEntries = entries);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _toggleSearchOptions() {
    setState(() {
      _searchOptionsExpanded = !_searchOptionsExpanded;
    });
  }

  void _onChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final useCase = ref.read(searchEntriesUseCaseProvider);
      final result = await useCase.execute(query);
      ref.read(searchResultsProvider.notifier).state = result;
    });
  }

  void _recordHistory() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final results = ref.read(searchResultsProvider);
    final topLang1s = results.take(5).map((e) => e.lang1).toList();
    ref
        .read(searchHistoryProvider.notifier)
        .record(query, results.length, topLang1s);
  }

  void _onSearchOptionsChanged(LibrarySearchOptions next) {
    if (next.filterCategories != _searchOptions.filterCategories) {
      unawaited(ref.read(filterCategoriesProvider.notifier).update(next.filterCategories));
    }
    setState(() => _searchOptions = next);
    ref.read(librarySearchPrefsStoreProvider).save(next).then((_) {
      if (mounted) {
        _onChanged(_controller.text);
      }
    });
  }

  Future<void> _showAddDialog() async {
    final lang1 = TextEditingController();
    final lang2 = TextEditingController();
    final memo = TextEditingController();
    final category = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('単語を登録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: lang1, decoration: const InputDecoration(labelText: 'ソース言語')),
              TextField(controller: lang2, decoration: const InputDecoration(labelText: 'ターゲット言語')),
              TextField(controller: memo, decoration: const InputDecoration(labelText: 'メモ')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'カテゴリ(//区切り)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                final now = DateTime.now();
                final entry = DictionaryEntry(
                  id: 'user-${now.microsecondsSinceEpoch}',
                  lang1: lang1.text.trim(),
                  lang2: lang2.text.trim(),
                  memo: memo.text.trim(),
                  categories: category.text.split('//').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  sourceType: EntrySourceType.manual,
                  createdAt: now,
                  updatedAt: now,
                );
                await ref.read(createOrUpdateUserEntryUseCaseProvider).execute(entry);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  _onChanged(_controller.text);
                  unawaited(_loadAllUserEntries());
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onAiButtonTapped() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    if (ref.read(currentUserInfoProvider) == null &&
        ref.read(webCookieUserProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI機能を使うには設定からGoogleでログインしてください'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final fixedMode = ref.read(aiModeSettingsProvider).effectiveFixedMode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiAssistSheet(
        word: query,
        autoExecuteMode: fixedMode,
        onSuccess: (result) {
          if (mounted) {
            ref.read(nzwJpAiUsageProvider.notifier).state =
                (remaining: result.remaining, limit: result.limit, resetDate: result.resetDate);
            ref.read(aiHistoryProvider.notifier).add(AiHistoryEntry(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              word: query,
              response: result.text,
              createdAt: DateTime.now(),
            ));
          }
        },
        onForbidden: () {
          if (mounted) {
            ref.read(nzwJpAiEnabledProvider.notifier).state = false;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('このアカウントはAI機能を利用できません'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        onRateLimit: () {
          if (mounted) {
            final usage = ref.read(nzwJpAiUsageProvider);
            final limit = usage?.limit ?? 10;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('今月のAI利用上限（$limit回）に達しました'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }

  List<DictionaryEntry> _visibleResults(
    List<DictionaryEntry> raw,
    String query,
    Set<String> filterCats,
  ) {
    final q = query.trim();

    // カテゴリフィルタが有効な場合はユーザー単語全件から絞り込む
    if (filterCats.isNotEmpty) {
      final inCat = _allUserEntries
          .where((e) => e.categories.any(filterCats.contains))
          .toList();
      if (q.isEmpty) return inCat;
      return inCat
          .where((e) => _searchOptions.entryMatchesQuery(e, q))
          .toList();
    }

    if (q.isEmpty) return raw;
    return raw.where((e) {
      if (!_searchOptions.includeExternalDictWhenSearching &&
          e.sourceType == EntrySourceType.external) {
        return false;
      }
      return _searchOptions.entryMatchesQuery(e, q);
    }).toList();
  }

  Widget _buildSearchBox(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  labelText: '検索',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isListening)
                        IconButton(
                          icon: const Icon(Icons.stop_circle),
                          color: Colors.red,
                          tooltip: '音声入力を停止',
                          onPressed: _stopListening,
                          style: IconButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                          ),
                        )
                      else if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: '入力をクリア',
                          style: IconButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                          ),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        )
                      else if (_speechAvailable)
                        IconButton(
                          icon: const Icon(Icons.mic),
                          tooltip: '音声入力',
                          onPressed: _startListening,
                          style: IconButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      Builder(builder: (context) {
                        final history = ref.watch(searchHistoryProvider);
                        if (history.isEmpty) return const SizedBox.shrink();
                        return MenuAnchor(
                          controller: _historyMenuController,
                          menuChildren: [
                            for (final e in history.take(20))
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.history, size: 16),
                                onPressed: () {
                                  _controller.text = e.query;
                                  _onChanged(e.query);
                                  FocusScope.of(context).unfocus();
                                },
                                child: Text(e.query),
                              ),
                          ],
                          child: IconButton(
                            tooltip: '検索履歴',
                            icon: const Icon(Icons.arrow_drop_down),
                            style: IconButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(32, 32),
                            ),
                            onPressed: () {
                              if (_historyMenuController.isOpen) {
                                _historyMenuController.close();
                              } else {
                                _historyMenuController.open();
                              }
                            },
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: IconButton(
                          tooltip: '検索オプション',
                          onPressed: _toggleSearchOptions,
                          style: IconButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                            backgroundColor: _searchOptionsExpanded
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                          icon: Icon(
                            Icons.tune,
                            size: 18,
                            color: _searchOptionsExpanded
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExternalLinkChips(DictLinkSettings settings) {
    final query = _controller.text;
    if (query.isEmpty) return const SizedBox.shrink();

    final aiEnabled = ref.watch(nzwJpAiEnabledProvider);
    final aiAvailable = aiEnabled != false;
    final showLinks = _searchOptions.showExternalLinks;
    final cs = Theme.of(context).colorScheme;

    final encoded = Uri.encodeComponent(query);
    final urlLinks = <String, ({String label, Uri url})>{
      'google': (label: 'Google', url: Uri.parse('https://www.google.com/search?q=$encoded')),
      'weblioJp': (label: 'Weblio', url: Uri.parse('https://www.weblio.jp/content/$encoded')),
      'weblioEj': (label: 'Weblio 英和', url: Uri.parse('http://ejje.weblio.jp/content/$encoded')),
      'weblioCj': (label: 'Weblio 日中・中日', url: Uri.parse('https://cjjc.weblio.jp/content/$encoded')),
      'kotobank': (label: 'コトバンク', url: Uri.parse('https://kotobank.jp/word/$encoded')),
      'wikipedia': (label: 'Wikipedia', url: Uri.parse('https://ja.wikipedia.org/wiki/$encoded')),
      'ctrans': (
        label: 'ctrans',
        url: Uri.parse('https://ctrans.org/search.php?word=$encoded&opts=fw&optext=${Uri.encodeComponent('中国語前方一致')}'),
      ),
    };

    // settings.effectiveOrder() の順序を尊重しながらチップを組み立てる
    final chips = <Widget>[];
    for (final id in settings.effectiveOrder()) {
      if (id == 'aiAssist') {
        if (aiAvailable && settings.isEnabled('aiAssist')) {
          chips.add(_chip(
            icon: Icons.auto_awesome,
            label: 'AI',
            onPressed: () { _recordHistory(); _onAiButtonTapped(); },
            color: cs.primaryContainer,
          ));
        }
      } else if (showLinks && settings.isEnabled(id) && urlLinks.containsKey(id)) {
        final link = urlLinks[id]!;
        chips.add(_chip(
          icon: Icons.open_in_new,
          label: link.label,
          onPressed: () {
            _recordHistory();
            launchUrl(link.url, mode: LaunchMode.externalApplication);
          },
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: Icon(icon, size: 14),
          label: Text(label),
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          color: color != null ? WidgetStatePropertyAll(color) : null,
        ),
      );

  Widget _buildOptionsPanel(List<String> availableCategories, Set<String> filterCats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: LibrarySearchOptionsPanel(
            options: _searchOptions.copyWith(filterCategories: filterCats),
            onChanged: _onSearchOptionsChanged,
            availableCategories: availableCategories,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userEntriesStreamProvider, (_, next) {
      if (next.hasValue && mounted) _loadAllUserEntries();
    });
    final theme = Theme.of(context);
    final dictSettings = ref.watch(dictLinkSettingsProvider);
    final results = ref.watch(searchResultsProvider);
    final filterCats = ref.watch(filterCategoriesProvider);
    final visible = _visibleResults(results, _controller.text, filterCats);
    final availableCategories = _allUserEntries
        .expand((e) => e.categories)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final isSearchActive = _focusNode.hasFocus ||
        _controller.text.isNotEmpty ||
        visible.isNotEmpty ||
        _searchOptionsExpanded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LangBridge'),
        actions: [
          IconButton(
            tooltip: '検索履歴',
            onPressed: () async {
              final query = await Navigator.push<String>(
                context,
                MaterialPageRoute<String>(
                    builder: (_) => const SearchHistoryPage()),
              );
              if (query != null && mounted) {
                _controller.text = query;
                _onChanged(query);
              }
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'マイ単語一覧',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const LibraryPage()),
            ),
            icon: const Icon(kWordBookNavigationIcon),
          ),
          IconButton(
            tooltip: '単語カード',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const FlashcardPage()),
            ),
            icon: const Icon(Icons.style_outlined),
          ),
          const AccountMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        label: const Text('単語登録'),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isSearchActive)
              // 未入力・非フォーカス時は検索ボックスを中央寄りに配置するための上余白
              const Spacer(),
            _buildSearchBox(theme),
            // LayoutBuilder で実際の残高さを取得し、オプションパネルを Stack オーバーレイにする。
            // _buildExternalLinkChips も Stack 内の Column に入れることで、
            // オプションパネルが外部リンクチップの上まで覆えるようにする。
            Expanded(
              flex: isSearchActive ? 1 : 2,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Builder(builder: (context) {
                            final aiUsage = ref.watch(nzwJpAiUsageProvider);
                            if (aiUsage == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              child: Text(
                                'AI月利用: ${aiUsage.limit - aiUsage.remaining}/${aiUsage.limit}回',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }),
                          _buildExternalLinkChips(dictSettings),
                          Expanded(
                            child: isSearchActive
                                ? _SearchResultsList(
                                    visible: visible,
                                    query: _controller.text.trim(),
                                    onBeforeNavigate: _recordHistory,
                                  )
                                : GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => FocusScope.of(context).unfocus(),
                                    child: const SizedBox.expand(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (_searchOptionsExpanded)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        // ConstrainedBox(maxHeight) + Column(mainAxisSize.min) + Flexible の組み合わせで
                        // 「コンテンツが小さければ自然な高さ、大きければスクロール」を実現する。
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                          child: Material(
                            color: theme.colorScheme.surface,
                            elevation: 2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: _buildOptionsPanel(availableCategories, filterCats),
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 検索結果リスト ─────────────────────────────────────────────

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.visible,
    required this.query,
    required this.onBeforeNavigate,
  });

  final List<DictionaryEntry> visible;
  final String query;
  final VoidCallback onBeforeNavigate;

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(context).colorScheme.primary;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final e = visible[i];
        return ListTile(
          dense: true,
          title: _highlighted(e.lang1, query, highlightColor),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _highlighted(e.lang2, query, highlightColor),
              if (e.memo.isNotEmpty)
                _highlighted(e.memo, query, highlightColor,
                    maxLines: null),
            ],
          ),
          onTap: () {
            onBeforeNavigate();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryDetailPage(entryId: e.id),
              ),
            );
          },
        );
      },
    );
  }
}

Widget _highlighted(String text, String query, Color color,
    {int? maxLines = 1}) {
  final overflow =
      maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible;
  if (query.isEmpty) {
    return Text(text, maxLines: maxLines, overflow: overflow);
  }
  final lower = text.toLowerCase();
  final lowerQ = query.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final idx = lower.indexOf(lowerQ, start);
    if (idx < 0) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
    spans.add(TextSpan(
      text: text.substring(idx, idx + lowerQ.length),
      style: TextStyle(
        color: color,
        backgroundColor: color.withValues(alpha: 0.2),
      ),
    ));
    start = idx + lowerQ.length;
  }
  return Text.rich(
    TextSpan(children: spans),
    maxLines: maxLines,
    overflow: overflow,
  );
}

// ---------------------------------------------------------------------------
// インアプリ APK アップデートダイアログ
// ---------------------------------------------------------------------------

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  // null = 未開始, 0.0〜1.0 = DL中, 1.0 完了
  double? _progress;
  String? _errorMessage;
  String? _apkPath;

  static const _channel = MethodChannel('jp.langbridge/install_apk');

  Future<void> _downloadAndInstall() async {
    setState(() {
      _progress = 0;
      _errorMessage = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/LangBridge_update.apk';

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(widget.info.downloadUrl));
      final res = await req.close();

      final total = res.contentLength;
      var received = 0;

      final file = File(savePath);
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      }
      await sink.close();
      client.close();

      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _apkPath = savePath;
      });

      await _channel.invokeMethod<void>('installApk', {'path': savePath});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _errorMessage = 'ダウンロードに失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final notes = info.releaseNotes;
    final isDownloading = _progress != null && _progress! < 1.0;
    final isDone = _apkPath != null;

    return AlertDialog(
      title: Text('v${info.latestVersion} にアップデート'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notes != null && notes.isNotEmpty) ...[
              const Text(
                '変更内容',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...notes.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 13)),
                      Expanded(child: Text(n, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                'ダウンロード中… ${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            if (isDone)
              const Text('ダウンロード完了。インストーラーを起動しています…', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      actions: [
        if (!info.isForceUpdate && !isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('後で'),
          ),
        if (!isDone && !isDownloading)
          FilledButton(
            onPressed: _downloadAndInstall,
            child: const Text('今すぐインストール'),
          ),
        if (isDone)
          FilledButton(
            onPressed: () async {
              await _channel.invokeMethod<void>('installApk', {'path': _apkPath!});
            },
            child: const Text('インストーラーを開く'),
          ),
      ],
    );
  }
}
