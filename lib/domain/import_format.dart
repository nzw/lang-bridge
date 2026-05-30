class ImportFormat {
  const ImportFormat({
    required this.lang1Headers,
    required this.lang2Headers,
    required this.memoHeaders,
    required this.categoryHeaders,
  });

  final Set<String> lang1Headers;
  final Set<String> lang2Headers;
  final Set<String> memoHeaders;
  final Set<String> categoryHeaders;

  static const supported = ImportFormat(
    // 旧ヘッダー名（日本語/中国語）との後方互換を維持
    lang1Headers: {'ソース言語', '日本語'},
    lang2Headers: {'ターゲット言語', '中国語'},
    memoHeaders: {'メモ', '説明', '備考'},
    categoryHeaders: {'カテゴリ'},
  );
}
