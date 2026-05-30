class GeminiResult {
  const GeminiResult({
    required this.text,
    required this.remaining,
    required this.limit,
    this.resetDate,
  });

  final String text;
  final int remaining;
  final int limit;
  /// ISO date string for the next monthly reset (e.g. "2025-05-01"). Null if not returned.
  final String? resetDate;
}
