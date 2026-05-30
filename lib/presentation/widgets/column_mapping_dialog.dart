import 'package:flutter/material.dart';

/// ダイアログの結果を表す sealed クラス。
sealed class ColumnMappingDialogResult {
  const ColumnMappingDialogResult();
}

/// このシートをスキップして次へ進む。
final class ColumnMappingSkip extends ColumnMappingDialogResult {
  const ColumnMappingSkip();
}

/// インポート全体を中止する。
final class ColumnMappingAbort extends ColumnMappingDialogResult {
  const ColumnMappingAbort();
}

/// 列マッピングを確定してインポートを続行する。
final class ColumnMappingConfirm extends ColumnMappingDialogResult {
  const ColumnMappingConfirm(this.mapping);
  final ColumnMappingResult mapping;
}

/// シートの列を単語帳フィールドに割り当てるダイアログ。
///
/// - [sheetName]: タイトルに表示するシート名（複数シート取込時）
/// - [sheetIndex]: 現在のシート番号（1始まり）
/// - [totalSheets]: 合計シート数
/// - [isBulk]: true の場合「全シートに適用」バナーを表示
/// 戻り値: [ColumnMappingConfirm]（確定）/ [ColumnMappingSkip]（このシートをスキップ）/
///        [ColumnMappingAbort]（全体を中止）
Future<ColumnMappingDialogResult> showColumnMappingDialog({
  required BuildContext context,
  required List<String> headers,
  required List<String> unknownHeaders,
  String? sheetName,
  int? sheetIndex,
  int? totalSheets,
  bool isBulk = false,
}) async {
  final result = await showDialog<ColumnMappingDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ColumnMappingDialog(
      headers: headers,
      sheetName: sheetName,
      sheetIndex: sheetIndex,
      totalSheets: totalSheets,
      isBulk: isBulk,
    ),
  );
  return result ?? const ColumnMappingAbort();
}

/// マッピング結果。
///
/// - [lang1Indexes]: ソース言語に使う列（複数可、スペース結合）
/// - [lang2Indexes]: ターゲット言語に使う列（複数可、スペース結合）
/// - [memoIndexes]: メモに使う列（複数可、「列名: 値」形式で改行結合）
/// - [categoryIndexes]: カテゴリに使う列（複数可）
class ColumnMappingResult {
  const ColumnMappingResult({
    required this.lang1Indexes,
    required this.lang2Indexes,
    this.memoIndexes = const [],
    this.categoryIndexes = const [],
  });

  final List<int> lang1Indexes;
  final List<int> lang2Indexes;
  final List<int> memoIndexes;
  final List<int> categoryIndexes;
}

// ---- ダイアログ本体 ----

class _ColumnMappingDialog extends StatefulWidget {
  const _ColumnMappingDialog({
    required this.headers,
    this.sheetName,
    this.sheetIndex,
    this.totalSheets,
    this.isBulk = false,
  });
  final List<String> headers;
  final String? sheetName;
  final int? sheetIndex;
  final int? totalSheets;
  final bool isBulk;

  @override
  State<_ColumnMappingDialog> createState() => _ColumnMappingDialogState();
}

class _ColumnMappingDialogState extends State<_ColumnMappingDialog> {
  final Set<int> _lang1 = {};
  final Set<int> _lang2 = {};
  final Set<int> _memo = {};
  final Set<int> _category = {};
  final ScrollController _contentScrollController = ScrollController();

  bool _showBottomFade = false;

  bool get _canConfirm => _lang1.isNotEmpty && _lang2.isNotEmpty;

  String _colLabel(int i) {
    final h = widget.headers[i];
    return h.isEmpty ? '列$i' : h;
  }

  @override
  void initState() {
    super.initState();
    // ヘッダー名から自動推測
    for (var i = 0; i < widget.headers.length; i++) {
      final h = widget.headers[i].trim().toLowerCase();
      if (_matchesLang1(h)) {
        _lang1.add(i);
      } else if (_matchesLang2(h)) {
        _lang2.add(i);
      } else if (_matchesMemo(h)) {
        _memo.add(i);
      } else if (_matchesCategory(h)) {
        _category.add(i);
      }
    }
    _contentScrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _contentScrollController
      ..removeListener(_updateScrollIndicators)
      ..dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_contentScrollController.hasClients || !mounted) return;
    final position = _contentScrollController.position;
    final canScroll = position.maxScrollExtent > 2;
    final shouldShowBottomFade = canScroll && position.pixels < position.maxScrollExtent - 2;
    if (_showBottomFade == shouldShowBottomFade) return;
    setState(() {
      _showBottomFade = shouldShowBottomFade;
    });
  }

  bool _matchesLang1(String h) =>
      {'ソース言語', '日本語', 'japanese', 'jp', '日語', 'にほんご', 'lang1'}.contains(h);
  bool _matchesLang2(String h) =>
      {'ターゲット言語', '中国語', '中文', 'chinese', 'zh', 'mandarin', '普通话', 'lang2'}
          .contains(h);
  bool _matchesMemo(String h) =>
      {'メモ', '説明', '備考', 'memo', 'note', 'notes', 'remark'}.contains(h);
  bool _matchesCategory(String h) =>
      {'カテゴリ', 'category', 'tag', 'タグ', 'genre'}.contains(h);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final progress = (widget.sheetIndex != null && widget.totalSheets != null)
        ? ' (${widget.sheetIndex}/${widget.totalSheets})'
        : '';
    final titleText = widget.sheetName != null
        ? '列の割り当て — ${widget.sheetName}$progress'
        : '列の割り当て';

    String bannerText;
    if (widget.isBulk) {
      bannerText = '全シートに共通の列マッピングを設定します。\n'
          'この設定がすべてのシートに適用されます。\n'
          '複数列を選ぶと値がスペースで結合されます。';
    } else if (widget.totalSheets != null && widget.totalSheets! > 1) {
      bannerText = 'このシートは標準のヘッダー名ではないため、'
          'どの列がどのデータかを指定してください。\n'
          'あと ${widget.totalSheets! - (widget.sheetIndex ?? 1)} シート残っています。\n'
          '複数列を選ぶと値がスペースで結合されます。';
    } else {
      bannerText = 'このシートは標準のヘッダー名ではないため、'
          'どの列がどのデータかを指定してください。\n'
          '複数列を選ぶと値がスペースで結合されます。';
    }

    return AlertDialog(
      title: Text(titleText),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Scrollbar(
                    controller: _contentScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _contentScrollController,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 説明バナー
                          _InfoBanner(text: bannerText),
                          const SizedBox(height: 14),

                          // シート列一覧（参考表示）
                          Text('シートの列一覧', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (var i = 0; i < widget.headers.length; i++)
                                Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: cs.secondaryContainer,
                                    child: Text('$i',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onSecondaryContainer)),
                                  ),
                                  label: Text(
                                    widget.headers[i].isEmpty ? '（空）' : widget.headers[i],
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ソース言語
                          _FieldSection(
                            icon: Icons.translate,
                            label: 'ソース言語',
                            description: 'すでに知っている言語（例: 日本語）',
                            required: true,
                            child: _ChipSelector(
                              headers: widget.headers,
                              selected: _lang1,
                              colLabel: _colLabel,
                              onToggle: (i, on) =>
                                  setState(() => on ? _lang1.add(i) : _lang1.remove(i)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ターゲット言語
                          _FieldSection(
                            icon: Icons.school_outlined,
                            label: 'ターゲット言語',
                            description: '学びたい言語（例: 中国語・英語など）',
                            required: true,
                            child: _ChipSelector(
                              headers: widget.headers,
                              selected: _lang2,
                              colLabel: _colLabel,
                              onToggle: (i, on) =>
                                  setState(() => on ? _lang2.add(i) : _lang2.remove(i)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // メモ
                          _FieldSection(
                            icon: Icons.notes_outlined,
                            label: 'メモ',
                            description: '補足情報・用例など（任意）',
                            required: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ChipSelector(
                                  headers: widget.headers,
                                  selected: _memo,
                                  colLabel: _colLabel,
                                  onToggle: (i, on) =>
                                      setState(() => on ? _memo.add(i) : _memo.remove(i)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // カテゴリ
                          _FieldSection(
                            icon: Icons.label_outline,
                            label: 'カテゴリ',
                            description: 'グループ分けに使う列（任意・複数可）',
                            required: false,
                            child: _ChipSelector(
                              headers: widget.headers,
                              selected: _category,
                              colLabel: _colLabel,
                              onToggle: (i, on) => setState(
                                  () => on ? _category.add(i) : _category.remove(i)),
                            ),
                          ),

                          // バリデーション警告
                          if (!_canConfirm) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(
                              text: 'ソース言語とターゲット言語は必須です。'
                                  'それぞれ少なくとも1列を選んでください。',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_showBottomFade)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.dialogTheme.backgroundColor?.withValues(alpha: 0.0) ??
                                    theme.colorScheme.surface.withValues(alpha: 0.0),
                                theme.dialogTheme.backgroundColor?.withValues(alpha: 0.92) ??
                                    theme.colorScheme.surface.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const ColumnMappingAbort()),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: const Text('中止'),
        ),
        if (!widget.isBulk)
          TextButton(
            onPressed: () => Navigator.pop(context, const ColumnMappingSkip()),
            child: const Text('スキップ'),
          ),
        FilledButton(
          onPressed: _canConfirm
              ? () => Navigator.pop(
                    context,
                    ColumnMappingConfirm(ColumnMappingResult(
                      lang1Indexes: _lang1.toList()..sort(),
                      lang2Indexes: _lang2.toList()..sort(),
                      memoIndexes: _memo.toList()..sort(),
                      categoryIndexes: _category.toList()..sort(),
                    )),
                  )
              : null,
          child: const Text('インポートする'),
        ),
      ],
    );
  }
}

// ---- 共通部品 ----

class _FieldSection extends StatelessWidget {
  const _FieldSection({
    required this.icon,
    required this.label,
    required this.description,
    required this.required,
    required this.child,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool required;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(label, style: theme.textTheme.labelMedium),
            if (required) ...[
              const SizedBox(width: 4),
              Text('必須',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.error)),
            ],
          ],
        ),
        Text(
          description,
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 列をFilterChipで複数選択するウィジェット。
class _ChipSelector extends StatelessWidget {
  const _ChipSelector({
    required this.headers,
    required this.selected,
    required this.colLabel,
    required this.onToggle,
  });

  final List<String> headers;
  final Set<int> selected;
  final String Function(int) colLabel;
  final void Function(int index, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < headers.length; i++)
          FilterChip(
            label: Text(colLabel(i)),
            selected: selected.contains(i),
            onSelected: (on) => onToggle(i, on),
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.error)),
          ),
        ],
      ),
    );
  }
}
