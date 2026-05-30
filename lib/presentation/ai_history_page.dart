import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../domain/ai_history_entry.dart';
import '../domain/dictionary_entry.dart';
import 'widgets/account_menu_button.dart';

class AiHistoryPage extends ConsumerWidget {
  const AiHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(aiHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 履歴'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: '全て削除',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context, ref),
            ),
          const AccountMenuButton(showGoHome: true),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Text('履歴はありません'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _HistoryCard(entry: history[i]),
            ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('履歴を全削除'),
        content: const Text('AI 履歴をすべて削除しますか？'),
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
    if (confirmed == true) {
      ref.read(aiHistoryProvider.notifier).clear();
    }
  }
}

class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.entry});
  final AiHistoryEntry entry;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _expanded = false;

  String _fmt(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}'
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

  Future<void> _register() async {
    await _showRegisterDialog(
      context: context,
      ref: ref,
      initialWord: widget.entry.word,
      initialMemo: widget.entry.response,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.entry;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
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
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
              ),
            ),
            if (!_expanded && entry.response.length > 120)
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text(
                  'もっと見る',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.primary),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_outlined, size: 15),
                  label: const Text('コピー'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.add_circle_outline, size: 15),
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
                decoration: const InputDecoration(labelText: 'ソース言語')),
            TextField(
                controller: lang2,
                decoration: const InputDecoration(labelText: 'ターゲット言語')),
            TextField(
                controller: memo,
                decoration: const InputDecoration(labelText: 'メモ'),
                maxLines: 3),
            TextField(
                controller: category,
                decoration:
                    const InputDecoration(labelText: 'カテゴリ(//区切り)')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル')),
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
            await ref
                .read(createOrUpdateUserEntryUseCaseProvider)
                .execute(entry);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
