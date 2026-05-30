import 'package:flutter/material.dart';

import '../../domain/library_search_options.dart';

/// 検索オプションのフォーム（マイ単語一覧・検索トップのアコーディオンで共有）。
class LibrarySearchOptionsPanel extends StatelessWidget {
  const LibrarySearchOptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    this.availableCategories = const [],
  });

  final LibrarySearchOptions options;
  final ValueChanged<LibrarySearchOptions> onChanged;
  final List<String> availableCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('一致の仕方'),
        const SizedBox(height: 8),
        SegmentedButton<LibraryMatchMode>(
          segments: const [
            ButtonSegment(
              value: LibraryMatchMode.contains,
              label: Text('部分'),
            ),
            ButtonSegment(
              value: LibraryMatchMode.prefix,
              label: Text('前方'),
            ),
            ButtonSegment(
              value: LibraryMatchMode.exact,
              label: Text('完全一致'),
            ),
          ],
          selected: {options.matchMode},
          onSelectionChanged: (s) {
            onChanged(options.copyWith(matchMode: s.first));
          },
        ),
        const SizedBox(height: 16),
        const Text('検索するフィールド'),
        CheckboxListTile(
          dense: true,
          title: const Text('ソース言語'),
          value: options.searchLang1,
          onChanged: (v) =>
              onChanged(options.copyWith(searchLang1: v ?? true)),
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('ターゲット言語'),
          value: options.searchLang2,
          onChanged: (v) =>
              onChanged(options.copyWith(searchLang2: v ?? true)),
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('メモ'),
          value: options.searchMemo,
          onChanged: (v) =>
              onChanged(options.copyWith(searchMemo: v ?? true)),
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('カテゴリ'),
          value: options.searchCategory,
          onChanged: (v) =>
              onChanged(options.copyWith(searchCategory: v ?? true)),
        ),
        if (availableCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('カテゴリで絞り込む'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('すべて'),
                selected: options.filterCategories.isEmpty,
                onSelected: (_) => onChanged(
                  options.copyWith(filterCategories: {}),
                ),
                visualDensity: VisualDensity.compact,
              ),
              for (final cat in availableCategories)
                FilterChip(
                  label: Text(cat),
                  selected: options.filterCategories.contains(cat),
                  onSelected: (_) {
                    final next = Set<String>.from(options.filterCategories);
                    if (next.contains(cat)) {
                      next.remove(cat);
                    } else {
                      next.add(cat);
                    }
                    onChanged(options.copyWith(filterCategories: next));
                  },
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Text('外部連携'),
        CheckboxListTile(
          dense: true,
          title: const Text('外部リンクを表示（Google 検索など）'),
          subtitle: const Text('設定画面で有効にしたサービスへのリンクを検索中に表示します'),
          value: options.showExternalLinks,
          onChanged: (v) =>
              onChanged(options.copyWith(showExternalLinks: v ?? true)),
        ),
      ],
    );
  }
}

String librarySearchOptionsSummary(LibrarySearchOptions o) {
  final fields = <String>[];
  if (o.searchLang1) {
    fields.add('ソース言語');
  }
  if (o.searchLang2) {
    fields.add('ターゲット言語');
  }
  if (o.searchMemo) {
    fields.add('メモ');
  }
  if (o.searchCategory) {
    fields.add('カテゴリ');
  }
  final match = switch (o.matchMode) {
    LibraryMatchMode.contains => '部分',
    LibraryMatchMode.prefix => '前方',
    LibraryMatchMode.exact => '完全一致',
  };
  return '$match · ${fields.join('・')}';
}
