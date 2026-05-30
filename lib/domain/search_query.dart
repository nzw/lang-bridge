class SearchQuery {
  SearchQuery(String raw) : raw = raw, normalized = _normalize(raw);

  final String raw;
  final String normalized;

  bool get isEmpty => normalized.isEmpty;

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
