import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../domain/saved_sync_url.dart';

class SavedUrlsPage extends ConsumerStatefulWidget {
  const SavedUrlsPage({super.key});

  @override
  ConsumerState<SavedUrlsPage> createState() => _SavedUrlsPageState();
}

class _SavedUrlsPageState extends ConsumerState<SavedUrlsPage> {
  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _modeLabel(AutoSyncMode m) => switch (m) {
        AutoSyncMode.addOnly => '追加のみ',
        AutoSyncMode.forceApply => '強制反映',
        AutoSyncMode.mergeConfirm => 'マージ確認',
      };

  String _modeDescription(AutoSyncMode m) => switch (m) {
        AutoSyncMode.addOnly => 'シートに新しい単語があればアプリに追加',
        AutoSyncMode.forceApply => 'シートの内容でアプリを上書き（削除あり）',
        AutoSyncMode.mergeConfirm => '差分を確認してから適用',
      };

  Future<void> _showEditDialog({SavedSyncUrl? entry}) async {
    final isNew = entry == null;
    final titleCtrl = TextEditingController(text: entry?.title ?? '');
    final urlCtrl = TextEditingController(text: entry?.url ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'URLを追加' : 'URLを編集'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'スプレッドシートURL',
                  border: OutlineInputBorder(),
                  hintText: 'https://docs.google.com/spreadsheets/d/…',
                ),
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'URLを入力してください';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null ||
                      !uri.host.contains('docs.google.com') ||
                      !uri.path.contains('/spreadsheets/d/')) {
                    return 'Google スプレッドシートの URL 形式で入力してください';
                  }
                  return null;
                },
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
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final title = titleCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (isNew) {
                ref.read(savedUrlsProvider.notifier).add(
                      SavedSyncUrl(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: title,
                        url: url,
                        createdAt: DateTime.now(),
                      ),
                    );
              } else {
                ref
                    .read(savedUrlsProvider.notifier)
                    .updateTitleAndUrl(entry.id, title, url);
              }
              Navigator.pop(ctx);
            },
            child: Text(isNew ? '追加' : '保存'),
          ),
        ],
      ),
    );

    titleCtrl.dispose();
    urlCtrl.dispose();
  }

  Future<void> _confirmDelete(SavedSyncUrl entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${entry.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(savedUrlsProvider.notifier).remove(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedUrls = ref.watch(savedUrlsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('保存済みスプレッドシート'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
      body: savedUrls.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '保存済みURLがありません',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '右下の「追加」から登録してください',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.only(
                  bottom: 96 + MediaQuery.of(context).padding.bottom),
              itemCount: savedUrls.length,
              separatorBuilder: (context, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = savedUrls[index];
                return _buildEntryTile(theme, entry);
              },
            ),
    );
  }

  Widget _buildEntryTile(ThemeData theme, SavedSyncUrl entry) {
    final autoEnabled = entry.isAutoSyncEnabled;
    return ExpansionTile(
      key: PageStorageKey(entry.id),
      tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      leading: autoEnabled
          ? Icon(Icons.sync, color: theme.colorScheme.primary, size: 22)
          : Icon(Icons.sync_disabled,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 22),
      title: Text(
        entry.title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            entry.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _dateChip(context,
                  icon: Icons.download_outlined,
                  label: '最終インポート',
                  date: entry.lastImportedAt),
              const SizedBox(width: 12),
              _dateChip(context,
                  icon: Icons.upload_outlined,
                  label: '最終エクスポート',
                  date: entry.lastExportedAt),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '編集',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(entry: entry),
          ),
          IconButton(
            tooltip: '削除',
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            onPressed: () => _confirmDelete(entry),
          ),
        ],
      ),
      children: [
        _buildAutoSyncSection(theme, entry),
      ],
    );
  }

  Widget _buildAutoSyncSection(ThemeData theme, SavedSyncUrl entry) {
    return StatefulBuilder(
      builder: (ctx, setLocal) {
        final enabled = entry.isAutoSyncEnabled;
        final cs = theme.colorScheme;

        void saveSettings({
          AutoSyncSchedule? schedule,
          AutoSyncMode? mode,
          String? sheetName,
          bool clearSheet = false,
        }) {
          ref.read(savedUrlsProvider.notifier).updateAutoSyncSettings(
                entry.id,
                schedule: schedule ?? entry.autoSyncSchedule,
                mode: mode ?? entry.autoSyncMode,
                sheetName:
                    clearSheet ? null : (sheetName ?? entry.autoSyncSheetName),
              );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            // 自動同期 ON/OFF トグル
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
              secondary: Icon(
                enabled ? Icons.sync : Icons.sync_disabled,
                size: 20,
                color: enabled ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              title: Text('自動同期',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: enabled
                  ? Text(
                      '次回: ${entry.nextAutoSyncAt != null ? "${_fmtDate(entry.nextAutoSyncAt)} 0:00 ごろ" : "—"}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.primary))
                  : Text('停止中',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
              value: enabled,
              onChanged: (on) => saveSettings(
                schedule: on ? AutoSyncSchedule.daily : AutoSyncSchedule.none,
              ),
            ),
            // 有効時のみ詳細設定を表示
            if (enabled) ...[
              const Divider(height: 1),
              const SizedBox(height: 12),
              // スケジュール
              _sectionLabel(theme, 'スケジュール'),
              const SizedBox(height: 6),
              SegmentedButton<AutoSyncSchedule>(
                segments: const [
                  ButtonSegment(
                      value: AutoSyncSchedule.daily,
                      label: Text('毎日'),
                      icon: Icon(Icons.today, size: 14)),
                  ButtonSegment(
                      value: AutoSyncSchedule.weekly,
                      label: Text('毎週'),
                      icon: Icon(Icons.date_range, size: 14)),
                ],
                selected: {entry.autoSyncSchedule == AutoSyncSchedule.none
                    ? AutoSyncSchedule.daily
                    : entry.autoSyncSchedule},
                onSelectionChanged: (s) => saveSettings(schedule: s.first),
              ),
              const SizedBox(height: 14),
              // 同期モード
              _sectionLabel(theme, '同期モード'),
              const SizedBox(height: 4),
              RadioGroup<AutoSyncMode>(
                groupValue: entry.autoSyncMode,
                onChanged: (v) {
                  if (v != null) saveSettings(mode: v);
                },
                child: Column(
                  children: AutoSyncMode.values
                      .map((m) => RadioListTile<AutoSyncMode>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: m,
                            title: Text(_modeLabel(m),
                                style: theme.textTheme.bodyMedium),
                            subtitle: Text(_modeDescription(m),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              // シート名
              _sectionLabel(theme, 'シート名（省略時: 最初のシートを使用）'),
              const SizedBox(height: 6),
              _SheetNameField(
                initialValue: entry.autoSyncSheetName ?? '',
                onSaved: (v) => saveSettings(
                    sheetName: v.isEmpty ? null : v, clearSheet: v.isEmpty),
              ),
              const SizedBox(height: 12),
              // 実績
              _infoRow(theme, '最終自動同期', _fmt(entry.lastAutoSyncAt)),
              const SizedBox(height: 4),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) => Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      );

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DateTime? date,
  }) {
    final theme = Theme.of(context);
    final color = date != null
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '$label: ${_fmt(date)}',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// シート名入力フィールド。フォーカスが外れたタイミングで onSaved を呼ぶ。
class _SheetNameField extends StatefulWidget {
  const _SheetNameField({required this.initialValue, required this.onSaved});
  final String initialValue;
  final void Function(String) onSaved;

  @override
  State<_SheetNameField> createState() => _SheetNameFieldState();
}

class _SheetNameFieldState extends State<_SheetNameField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_SheetNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _ctrl.text != widget.initialValue) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: '例: シート1',
        isDense: true,
      ),
      onTapOutside: (_) => widget.onSaved(_ctrl.text.trim()),
      onSubmitted: (v) => widget.onSaved(v.trim()),
    );
  }
}
