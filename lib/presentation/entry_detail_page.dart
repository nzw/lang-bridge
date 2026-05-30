import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/providers.dart';
import '../domain/dictionary_entry.dart';

class EntryDetailPage extends ConsumerStatefulWidget {
  const EntryDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  DictionaryEntry? _entry;
  bool _editing = false;
  bool _saving = false;

  // 編集用コントローラー
  late final TextEditingController _lang1Ctrl;
  late final TextEditingController _lang2Ctrl;
  late final TextEditingController _memoCtrl;
  late final TextEditingController _newCategoryCtrl;
  List<String> _editingCategories = [];

  @override
  void initState() {
    super.initState();
    _lang1Ctrl = TextEditingController();
    _lang2Ctrl = TextEditingController();
    _memoCtrl = TextEditingController();
    _newCategoryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _lang1Ctrl.dispose();
    _lang2Ctrl.dispose();
    _memoCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    final e = _entry;
    if (e == null) return;
    _lang1Ctrl.text = e.lang1;
    _lang2Ctrl.text = e.lang2;
    _memoCtrl.text = e.memo;
    _editingCategories = List.from(e.categories);
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  Future<void> _saveEditing() async {
    final entry = _entry;
    if (entry == null) return;
    final lang1 = _lang1Ctrl.text.trim();
    final lang2 = _lang2Ctrl.text.trim();
    if (lang1.isEmpty || lang2.isEmpty) return;

    setState(() => _saving = true);
    final updated = entry.copyWith(
      lang1: lang1,
      lang2: lang2,
      memo: _memoCtrl.text.trim(),
      categories: List.from(_editingCategories),
      updatedAt: DateTime.now(),
    );
    await ref.read(userRepositoryProvider).upsert(updated);
    if (!mounted) return;
    setState(() {
      _entry = updated;
      _editing = false;
      _saving = false;
    });
  }

  Future<void> _confirmDelete(DictionaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${entry.lang1} / ${entry.lang2}」を削除しますか？\nこの操作は元に戻せません。'),
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
    await ref.read(userRepositoryProvider).deleteById(entry.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _toggleFavorite() async {
    final entry = _entry;
    if (entry == null) return;
    final updated = entry.copyWith(isFavorite: !entry.isFavorite);
    await ref.read(userRepositoryProvider).upsert(updated);
    if (!mounted) return;
    setState(() => _entry = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder(
      future: ref.read(getEntryDetailUseCaseProvider).execute(widget.entryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null &&
            _entry == null) {
          _entry = snapshot.data;
        }
        final entry = _entry;

        return Scaffold(
          appBar: AppBar(
            title: Text(_editing ? '編集' : '詳細'),
            actions: [
              if (entry != null && !_editing) ...[
                IconButton(
                  tooltip: entry.isFavorite ? 'お気に入り解除' : 'お気に入りに追加',
                  icon: Icon(
                    entry.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: entry.isFavorite ? cs.primary : null,
                  ),
                  onPressed: _toggleFavorite,
                ),
                IconButton(
                  tooltip: '編集',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _startEditing,
                ),
                IconButton(
                  tooltip: '削除',
                  icon: Icon(Icons.delete_outline_rounded,
                      color: cs.error),
                  onPressed: () => _confirmDelete(entry),
                ),
              ],
              if (_editing) ...[
                TextButton(
                  onPressed: _saving ? null : _cancelEditing,
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _saveEditing,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          body: snapshot.connectionState != ConnectionState.done && entry == null
              ? const Center(child: CircularProgressIndicator())
              : entry == null
                  ? const Center(child: Text('データが見つかりません'))
                  : _editing
                      ? _buildEditBody(context, theme, cs, entry)
                      : _buildViewBody(context, theme, cs, entry),
        );
      },
    );
  }

  // ── 閲覧モード ────────────────────────────────────────────

  Widget _buildViewBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    DictionaryEntry entry,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 語彙カード
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant, width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LangRow(
                    label: 'ソース言語',
                    text: entry.lang1,
                    textStyle: theme.textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    labelColor: cs.primary,
                    onCopy: () => _copyToClipboard(entry.lang1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: cs.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.swap_vert_rounded,
                              size: 18, color: cs.onSurfaceVariant),
                        ),
                        Expanded(child: Divider(color: cs.outlineVariant)),
                      ],
                    ),
                  ),
                  _LangRow(
                    label: 'ターゲット言語',
                    text: entry.lang2,
                    textStyle: theme.textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    labelColor: cs.secondary,
                    onCopy: () => _copyToClipboard(entry.lang2),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (entry.memo.isNotEmpty) ...[
            Row(
              children: [
                _SectionLabel(label: 'メモ', icon: Icons.notes_outlined),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _copyToClipboard(entry.memo),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.copy_outlined, size: 14,
                        color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant, width: 0.8),
              ),
              child: Text(
                entry.memo,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (entry.categories.isNotEmpty) ...[
            _SectionLabel(
                label: 'カテゴリ', icon: Icons.label_outline_rounded),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final cat in entry.categories)
                  Chip(
                    label: Text(cat),
                    labelStyle: theme.textTheme.labelMedium
                        ?.copyWith(color: cs.onSecondaryContainer),
                    backgroundColor: cs.secondaryContainer,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          _SectionLabel(label: '情報', icon: Icons.info_outline_rounded),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant, width: 0.8),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.bar_chart_rounded,
                  label: '習熟度',
                  trailing: _ReviewScoreWidget(score: entry.reviewScore),
                ),
                Divider(height: 1, indent: 16, color: cs.outlineVariant),
                _InfoRow(
                  icon: Icons.source_outlined,
                  label: 'ソース',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sourceLabel(entry.sourceType),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      if (entry.sourceUrl != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _openUrl(entry.sourceUrl!),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (entry.createdAt != null) ...[
                  Divider(height: 1, indent: 16, color: cs.outlineVariant),
                  _InfoRow(
                    icon: Icons.download_outlined,
                    label: '取込日時',
                    trailing: Text(
                      _formatDateTime(entry.createdAt!),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
                if (entry.updatedAt != null) ...[
                  Divider(height: 1, indent: 16, color: cs.outlineVariant),
                  _InfoRow(
                    icon: Icons.edit_calendar_outlined,
                    label: '更新日時',
                    trailing: Text(
                      _formatDateTime(entry.updatedAt!),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 編集モード ────────────────────────────────────────────

  Widget _buildEditBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    DictionaryEntry entry,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ソース言語
          TextField(
            controller: _lang1Ctrl,
            decoration: InputDecoration(
              labelText: 'ソース言語',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.translate, color: cs.primary),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // ターゲット言語
          TextField(
            controller: _lang2Ctrl,
            decoration: InputDecoration(
              labelText: 'ターゲット言語',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.school_outlined, color: cs.secondary),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // メモ
          TextField(
            controller: _memoCtrl,
            decoration: const InputDecoration(
              labelText: 'メモ（任意）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 20),

          // カテゴリ
          _SectionLabel(
              label: 'カテゴリ', icon: Icons.label_outline_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final cat in _editingCategories)
                Chip(
                  label: Text(cat),
                  labelStyle: theme.textTheme.labelMedium
                      ?.copyWith(color: cs.onSecondaryContainer),
                  backgroundColor: cs.secondaryContainer,
                  side: BorderSide.none,
                  deleteIcon: Icon(Icons.close,
                      size: 16, color: cs.onSecondaryContainer),
                  onDeleted: () =>
                      setState(() => _editingCategories.remove(cat)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCategoryCtrl,
                  decoration: const InputDecoration(
                    hintText: 'カテゴリを追加',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addCategory(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCategory,
                icon: const Icon(Icons.add),
                tooltip: '追加',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addCategory() {
    final cat = _newCategoryCtrl.text.trim();
    if (cat.isEmpty || _editingCategories.contains(cat)) return;
    setState(() => _editingCategories.add(cat));
    _newCategoryCtrl.clear();
  }

  String _sourceLabel(EntrySourceType type) {
    return switch (type) {
      EntrySourceType.external => '辞書データ',
      EntrySourceType.userSheet => 'スプレッドシート取込',
      EntrySourceType.manual => '手動登録',
    };
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URLを開けませんでした')),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('コピーしました'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 補助ウィジェット ─────────────────────────────────────────

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.label,
    required this.text,
    required this.textStyle,
    required this.labelColor,
    this.onCopy,
  });

  final String label;
  final String text;
  final TextStyle textStyle;
  final Color labelColor;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: labelColor,
                    letterSpacing: 0.5,
                  ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.copy_outlined, size: 14, color: labelColor),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(text, style: textStyle),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _ReviewScoreWidget extends StatelessWidget {
  const _ReviewScoreWidget({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const maxScore = 5;
    final clamped = score.clamp(0, maxScore);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < maxScore; i++)
          Icon(
            i < clamped ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: i < clamped ? cs.primary : cs.outlineVariant,
          ),
        const SizedBox(width: 4),
        Text(
          '$score',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
