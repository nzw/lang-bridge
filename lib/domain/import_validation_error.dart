class ImportValidationError implements Exception {
  const ImportValidationError({
    required this.message,
    this.missingHeaders = const [],
    this.unknownHeaders = const [],
    this.missingRequiredCellCount = 0,
  });

  final String message;
  final List<String> missingHeaders;
  final List<String> unknownHeaders;
  final int missingRequiredCellCount;
}
