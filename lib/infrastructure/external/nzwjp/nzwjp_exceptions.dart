class NzwJpUnauthorizedException implements Exception {
  const NzwJpUnauthorizedException();
}

class NzwJpForbiddenException implements Exception {
  const NzwJpForbiddenException();
}

class NzwJpRateLimitException implements Exception {
  const NzwJpRateLimitException();
}

class NzwJpApiException implements Exception {
  const NzwJpApiException(this.message);
  final String message;
  @override
  String toString() => 'NzwJpApiException: $message';
}
