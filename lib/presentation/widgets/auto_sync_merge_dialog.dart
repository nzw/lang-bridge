import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/providers.dart';
import '../../domain/saved_sync_url.dart';

/// mergeConfirm モードで競合・新規・書き出し対象を確認するダイアログ。
class AutoSyncMergeDialog extends ConsumerStatefulWidget {
  const AutoSyncMergeDialog({
    super.key,
    required this.savedUrl,
    required this.result,
  });

  final SavedSyncUrl savedUrl;
  final AutoSyncResult result;

  @override
  ConsumerState<AutoSyncMergeDialog> createState() =>
      _AutoSyncMergeDialogState();
}

class _AutoSyncMergeDialogState extends ConsumerState<AutoSyncMergeDialog> {
  // 各競合エントリの選択: true=シート版を使用, false=アプリ版を維持
  late final Map<String, bool> _conflictChoices;
  bool _addNewFromSheet = true;
  bool _exportManualEntries = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _conflictChoices = {
      for (final c in widget.result.conflicts) c.appEntry.id: false,
    };
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final exportedSheet =
          await ref.read(autoSyncUseCaseProvider).applyMergeConflicts(
                savedUrl: widget.savedUrl,
                conflicts: widget.result.conflicts,
                resolvedConflicts: _conflictChoices,
                newEntries: widget.result.newEntriesFromSheet,
                addNewFromSheet: _addNewFromSheet,
                exportManualEntries: _exportManualEntries,
                manualEntries: widget.result.manualEntriesToExport,
              );
      await ref
          .read(savedUrlsProvider.notifier)
          .updateLastAutoSyncAt(widget.savedUrl.id);
      if (mounted) {
        Navigator.of(context).pop();
        _showDoneSnackBar(exportedSheet);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('適用に失敗しました: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showDoneSnackBar(String? exportedSheet) {
    final msg = exportedSheet != null
        ? 'マージを適用しました。シート「$exportedSheet」に書き出しました。'
        : 'マージを適用しました。';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflicts = widget.result.conflicts;
    final newFromSheet = widget.result.newEntriesFromSheet;
    final manualEntries = widget.result.manualEntriesToExport;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync_problem_outlined),
          const SizedBox(width: 8),
          Text(
            '自動同期 — 確認',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            // ── 競合エントリ ──────────────────────────────────────────────
            if (conflicts.isNotEmpty) ...[
              _sectionHeader(theme, '競合（${conflicts.length}件）',
                  'アプリとシートで内容が異なります'),
              ...conflicts.map((c) => _conflictTile(theme, c)),
            ],

            // ── シート新規追加 ─────────────────────────────────────────────
            if (newFromSheet.isNotEmpty) ...[
              _sectionHeader(theme, 'シート新規追加（${newFromSheet.length}件）',
                  'シート側に追加されたエントリをアプリに取り込みますか？'),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  newFromSheet.length == 1
                      ? '「${newFromSheet.first.lang1}」など 1件をアプリに追加'
                      : '${newFromSheet.length}件をアプリに追加する',
                ),
                value: _addNewFromSheet,
                onChanged: (v) => setState(() => _addNewFromSheet = v),
              ),
            ],

            // ── アプリ追加分の書き出し ─────────────────────────────────────
            if (manualEntries.isNotEmpty) ...[
              _sectionHeader(theme, 'アプリ追加分（${manualEntries.length}件）',
                  'アプリで追加した単語をシートの新しいシートに書き出しますか？'),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  '${manualEntries.length}件をシートに書き出す',
                ),
                subtitle: const Text('新しいシート「LangBridge追加_YYYYMMDD」が作成されます'),
                value: _exportManualEntries,
                onChanged: (v) => setState(() => _exportManualEntries = v),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          child: const Text('後で'),
        ),
        FilledButton(
          onPressed: _applying ? null : _apply,
          child: _applying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('適用'),
        ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const Divider(height: 12),
        ],
      ),
    );
  }

  Widget _conflictTile(ThemeData theme, AutoSyncConflict conflict) {
    final useSheet = _conflictChoices[conflict.appEntry.id] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${conflict.appEntry.lang1}  /  ${conflict.appEntry.lang2}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _versionCard(
                  theme,
                  label: 'アプリ',
                  memo: conflict.appEntry.memo,
                  selected: !useSheet,
                  onTap: () => setState(
                      () => _conflictChoices[conflict.appEntry.id] = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _versionCard(
                  theme,
                  label: 'シート',
                  memo: conflict.sheetMemo,
                  selected: useSheet,
                  onTap: () => setState(
                      () => _conflictChoices[conflict.appEntry.id] = true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _versionCard(
    ThemeData theme, {
    required String label,
    required String memo,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final borderColor =
        selected ? theme.colorScheme.primary : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected)
                  Icon(Icons.check_circle,
                      size: 14, color: theme.colorScheme.primary)
                else
                  Icon(Icons.radio_button_unchecked,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              memo.isEmpty ? '（メモなし）' : memo,
              style: theme.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
