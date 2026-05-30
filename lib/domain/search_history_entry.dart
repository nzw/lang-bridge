class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.query,
    required this.resultCount,
    required this.topLang1s,
    required this.searchedAt,
  });

  final String query;
  final int resultCount;
  final List<String> topLang1s;
  final DateTime searchedAt;

  Map<String, dynamic> toJson() => {
        'query': query,
        'resultCount': resultCount,
        'topLang1s': topLang1s,
        'searchedAt': searchedAt.toIso8601String(),
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> j) =>
      SearchHistoryEntry(
        query: j['query'] as String,
        resultCount: (j['resultCount'] as int?) ?? 0,
        topLang1s:
            (j['topLang1s'] as List<dynamic>?)?.cast<String>() ?? const [],
        searchedAt: DateTime.parse(j['searchedAt'] as String),
      );
}
