import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../domain/ai_history_entry.dart';
import '../domain/dictionary_entry.dart';
import '../domain/search_history_entry.dart';

class SearchHistoryPage extends ConsumerWidget {
  const SearchHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchHistory = ref.watch(searchHistoryProvider);
    final aiHistory = ref.watch(aiHistoryProvider);
    final theme = Theme.of(context);

    final items = <_Item>[
      for (final e in searchHistory) _Item(e.searchedAt, e),
      for (final e in aiHistory) _Item(e.createdAt, e),
    ]..sort((a, b) => b.ts.compareTo(a.ts));

    final isEmpty = items.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('検索履歴'),
        actions: [
          if (!isEmpty)
            PopupMenuButton<_ClearMode>(
              tooltip: '削除',
              icon: const Icon(Icons.delete_sweep_outlined),
              onSelected: (mode) => _confirmClear(context, ref, mode),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ClearMode.all,
                  child: Text('すべて削除'),
                ),
                PopupMenuItem(
                  value: _ClearMode.search,
                  child: Text('キーワード履歴のみ削除'),
                ),
                PopupMenuItem(
                  value: _ClearMode.ai,
                  child: Text('AI履歴のみ削除'),
                ),
              ],
            ),
        ],
      ),
      body: isEmpty
          ? Center(
              child: Text(
                '履歴はありません',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = items[i];
                if (item.data is SearchHistoryEntry) {
                  return _SearchTile(
                    entry: item.data as SearchHistoryEntry,
                    onTap: () =>
                        Navigator.pop(context, (item.data as SearchHistoryEntry).query),
                  );
                } else {
                  return _AiCard(entry: item.data as AiHistoryEntry);
                }
              },
            ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    _ClearMode mode,
  ) async {
    final label = switch (mode) {
      _ClearMode.all => 'すべての履歴',
      _ClearMode.search => 'キーワード検索履歴',
      _ClearMode.ai => 'AI履歴',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label を削除'),
        content: Text('$label をすべて削除しますか？'),
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
    if (ok == true) {
      if (mode == _ClearMode.all || mode == _ClearMode.search) {
        ref.read(searchHistoryProvider.notifier).clear();
      }
      if (mode == _ClearMode.all || mode == _ClearMode.ai) {
        ref.read(aiHistoryProvider.notifier).clear();
      }
    }
  }
}

enum _ClearMode { all, search, ai }

class _Item {
  const _Item(this.ts, this.data);
  final DateTime ts;
  final Object data;
}

// ── キーワード検索タイル ──────────────────────────────────────────────

class _SearchTile extends ConsumerWidget {
  const _SearchTile({required this.entry, required this.onTap});

  final SearchHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = entry.searchedAt;
    final dateStr =
        '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      leading: const Icon(Icons.history, size: 20),
      title: Text(entry.query, style: theme.textTheme.bodyMedium),
      subtitle: entry.topLang1s.isNotEmpty
          ? Text(
              entry.topLang1s.join('、'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.resultCount}件  $dateStr',
            style:
                theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: '削除',
            onPressed: () =>
                ref.read(searchHistoryProvider.notifier).remove(entry.query),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ── AI 履歴カード ─────────────────────────────────────────────────────

class _AiCard extends ConsumerStatefulWidget {
  const _AiCard({required this.entry});
  final AiHistoryEntry entry;

  @override
  ConsumerState<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends ConsumerState<_AiCard> {
  bool _expanded = false;

  String _fmt(DateTime dt) =>
      '${dt.month}/${dt.day}'
      ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.response));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('コピーしました'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.entry;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: cs.primaryContainer.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.word,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _fmt(entry.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  IconButton(
                    tooltip: '削除',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                    onPressed: () =>
                        ref.read(aiHistoryProvider.notifier).remove(entry.id),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  entry.response,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
                ),
              ),
              if (!_expanded && entry.response.length > 150)
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Text(
                    'もっと見る',
                    style:
                        theme.textTheme.labelSmall?.copyWith(color: cs.primary),
                  ),
                ),
              const Divider(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_outlined, size: 14),
                    label: const Text('コピー'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showRegisterDialog(
                      context: context,
                      ref: ref,
                      initialWord: entry.word,
                      initialMemo: entry.response,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 14),
                    label: const Text('単語登録'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showRegisterDialog({
  required BuildContext context,
  required WidgetRef ref,
  String? initialWord,
  String? initialMemo,
}) async {
  final lang1 = TextEditingController(text: initialWord ?? '');
  final lang2 = TextEditingController();
  final memo = TextEditingController(text: initialMemo ?? '');
  final category = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('単語を登録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lang1,
              decoration: const InputDecoration(labelText: 'ソース言語'),
            ),
            TextField(
              controller: lang2,
              decoration: const InputDecoration(labelText: 'ターゲット言語'),
            ),
            TextField(
              controller: memo,
              decoration: const InputDecoration(labelText: 'メモ'),
              maxLines: 3,
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'カテゴリ(//区切り)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            final now = DateTime.now();
            final entry = DictionaryEntry(
              id: 'user-${now.microsecondsSinceEpoch}',
              lang1: lang1.text.trim(),
              lang2: lang2.text.trim(),
              memo: memo.text.trim(),
              categories: category.text
                  .split('//')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              sourceType: EntrySourceType.manual,
              createdAt: now,
              updatedAt: now,
            );
            await ref.read(createOrUpdateUserEntryUseCaseProvider).execute(entry);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
