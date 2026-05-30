import 'dictionary_entry.dart';

/// マイ単語一覧・トップ検索で共有する検索オプション（永続化用）。
class LibrarySearchOptions {
  const LibrarySearchOptions({
    this.matchMode = LibraryMatchMode.contains,
    this.searchLang1 = true,
    this.searchLang2 = true,
    this.searchMemo = true,
    this.searchCategory = true,
    this.includeExternalDictWhenSearching = false,
    this.showExternalLinks = true,
    this.filterCategories = const {},
  });

  final LibraryMatchMode matchMode;
  final bool searchLang1;
  final bool searchLang2;
  final bool searchMemo;
  final bool searchCategory;

  /// 検索語があるとき、外部辞書 API も併用する（オフなら端末のユーザー単語のみ）。
  final bool includeExternalDictWhenSearching;

  /// インクリメンタルサーチ時に外部連携リンク（Google 検索等）を表示する。
  final bool showExternalLinks;

  /// カテゴリフィルタ（空セット = 絞り込みなし）。ユーザー単語にのみ適用。永続化しない。
  final Set<String> filterCategories;

  LibrarySearchOptions copyWith({
    LibraryMatchMode? matchMode,
    bool? searchLang1,
    bool? searchLang2,
    bool? searchMemo,
    bool? searchCategory,
    bool? includeExternalDictWhenSearching,
    bool? showExternalLinks,
    Set<String>? filterCategories,
  }) {
    return LibrarySearchOptions(
      matchMode: matchMode ?? this.matchMode,
      searchLang1: searchLang1 ?? this.searchLang1,
      searchLang2: searchLang2 ?? this.searchLang2,
      searchMemo: searchMemo ?? this.searchMemo,
      searchCategory: searchCategory ?? this.searchCategory,
      includeExternalDictWhenSearching:
          includeExternalDictWhenSearching ?? this.includeExternalDictWhenSearching,
      showExternalLinks: showExternalLinks ?? this.showExternalLinks,
      filterCategories: filterCategories ?? this.filterCategories,
    );
  }

  Map<String, dynamic> toJson() => {
        'matchMode': matchMode.name,
        'searchLang1': searchLang1,
        'searchLang2': searchLang2,
        'searchMemo': searchMemo,
        'searchCategory': searchCategory,
        'includeExternalDictWhenSearching': includeExternalDictWhenSearching,
        'showExternalLinks': showExternalLinks,
      };

  static LibrarySearchOptions fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LibrarySearchOptions();
    LibraryMatchMode mode = LibraryMatchMode.contains;
    final m = json['matchMode'] as String?;
    if (m != null) {
      mode = LibraryMatchMode.values.firstWhere(
        (e) => e.name == m,
        orElse: () => LibraryMatchMode.contains,
      );
    }
    return LibrarySearchOptions(
      matchMode: mode,
      // 旧キー名（searchJapanese/searchChinese）との後方互換
      searchLang1: (json['searchLang1'] ?? json['searchJapanese']) as bool? ?? true,
      searchLang2: (json['searchLang2'] ?? json['searchChinese']) as bool? ?? true,
      searchMemo: json['searchMemo'] as bool? ?? true,
      searchCategory: json['searchCategory'] as bool? ?? true,
      // 旧キー名（includeHokujiroWhenSearching）との後方互換
      includeExternalDictWhenSearching:
          (json['includeExternalDictWhenSearching'] ??
              json['includeHokujiroWhenSearching']) as bool? ?? false,
      showExternalLinks: json['showExternalLinks'] as bool? ?? true,
    );
  }
}

enum LibraryMatchMode {
  contains,
  prefix,
  exact,
}

extension LibrarySearchOptionsMatching on LibrarySearchOptions {
  /// [rawQuery] が空なら常に true（一覧全件扱い）。
  bool entryMatchesQuery(DictionaryEntry e, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    bool testField(String text) {
      final v = text.toLowerCase();
      switch (matchMode) {
        case LibraryMatchMode.exact:
          return v == q;
        case LibraryMatchMode.prefix:
          return v.startsWith(q);
        case LibraryMatchMode.contains:
          return v.contains(q);
      }
    }

    if (searchLang1 && testField(e.lang1)) return true;
    if (searchLang2 && testField(e.lang2)) return true;
    if (searchMemo && testField(e.memo)) return true;
    if (searchCategory) {
      for (final c in e.categories) {
        if (testField(c)) return true;
      }
    }
    return false;
  }
}
