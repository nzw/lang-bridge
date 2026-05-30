import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../domain/dictionary_entry.dart';
import '../domain/library_search_options.dart';
import 'entry_detail_page.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/library_search_options_panel.dart';

/// シート取込・手動登録したユーザー単語を一覧し、細かい検索オプションを保存して使い回せる画面。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  LibrarySearchOptions _options = const LibrarySearchOptions();
  List<DictionaryEntry> _allUserEntries = [];
  List<DictionaryEntry> _userRows = [];
  List<DictionaryEntry> _externalRows = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final loaded = await ref.read(librarySearchPrefsStoreProvider).load();
      if (mounted) {
        setState(() => _options = loaded);
      }
    } catch (_) {
      // 既定オプションのまま続行
    }
    await _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _persistOptions() async {
    await ref.read(librarySearchPrefsStoreProvider).save(_options);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await ref.read(userRepositoryProvider).listAll();
      final q = _queryController.text.trim();
      final cats = ref.read(filterCategoriesProvider);
      final base = cats.isEmpty
          ? user
          : user.where((e) => e.categories.any(cats.contains)).toList();
      final filtered =
          base.where((e) => _options.entryMatchesQuery(e, q)).toList();
      List<DictionaryEntry> hoku = [];
      if (q.isNotEmpty && _options.includeExternalDictWhenSearching) {
        final merged = await ref.read(searchEntriesUseCaseProvider).execute(q);
        hoku = merged
            .where((e) => e.sourceType == EntrySourceType.external)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _allUserEntries = user;
        _userRows = filtered;
        _externalRows = hoku;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userRows = [];
        _externalRows = [];
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _refresh);
  }

  Future<void> _onOptionsChanged(LibrarySearchOptions next) async {
    if (next.filterCategories != _options.filterCategories) {
      await ref.read(filterCategoriesProvider.notifier).update(next.filterCategories);
    }
    setState(() => _options = next);
    await _persistOptions();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userEntriesStreamProvider, (_, next) {
      if (next.hasValue && mounted) _refresh();
    });
    final theme = Theme.of(context);
    final filterCats = ref.watch(filterCategoriesProvider);
    final availableCategories = _allUserEntries
        .expand((e) => e.categories)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイ単語一覧'),
        actions: [
          IconButton(
            tooltip: '再読込',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          const AccountMenuButton(showGoHome: true),
        ],
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // ── 検索フィールド ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _queryController,
                onChanged: (v) {
                  setState(() {});
                  _onQueryChanged(v);
                },
                decoration: InputDecoration(
                  labelText: '絞り込み（マイ単語＋オプション）',
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _queryController.clear();
                            _onQueryChanged('');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),

          // ── 検索オプション（アコーディオン） ────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const PageStorageKey<String>('library_search_options'),
                  leading: Icon(
                    Icons.tune_outlined,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('検索オプション'),
                  subtitle: Text(
                    librarySearchOptionsSummary(_options),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    LibrarySearchOptionsPanel(
                      options: _options.copyWith(filterCategories: filterCats),
                      onChanged: _onOptionsChanged,
                      availableCategories: availableCategories,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 区切り線 ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),

          // ── ローディングバー ────────────────────────────
          if (_loading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 3),
            ),

          // ── エラー表示 ──────────────────────────────────
          if (!_loading && _loadError != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('読み込みに失敗しました',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      SelectableText(
                        _loadError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              ),
            )

          // ── 結果一覧 ────────────────────────────────────
          else if (!_loading) ...[
            SliverToBoxAdapter(
              child: _sectionHeader(
                  theme, '端末の単語（シート取込・手動）', _userRows.length),
            ),
            if (_userRows.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '該当する単語がありません。Google Sheets 同期で取り込むか、検索トップから単語登録してください。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: _userRows.length,
                itemBuilder: (ctx, i) => _entryTile(ctx, _userRows[i]),
              ),
            if (_externalRows.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _sectionHeader(
                    theme, '外部辞書（参照）', _externalRows.length),
              ),
              SliverList.builder(
                itemCount: _externalRows.length,
                itemBuilder: (ctx, i) => _entryTile(ctx, _externalRows[i]),
              ),
            ],
            SliverPadding(padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom)),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text('$count 件', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _entryTile(BuildContext context, DictionaryEntry e) {
    final sub = e.memo.isEmpty ? e.categories.join(', ') : e.memo;
    return ListTile(
      title: Text('${e.lang1} ／ ${e.lang2}'),
      subtitle: Text(
        sub.isEmpty ? '—' : sub,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        e.sourceType == EntrySourceType.external
            ? Icons.cloud_outlined
            : Icons.phone_android_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EntryDetailPage(entryId: e.id),
        ),
      ).then((_) => _refresh()),
    );
  }
}
