/// ドメイン層の基底例外。インフラ依存を持たない純粋なビジネスエラー。
sealed class DomainException implements Exception {
  const DomainException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// エントリが見つからなかった場合。
final class EntryNotFoundException extends DomainException {
  const EntryNotFoundException(String id)
      : entryId = id,
        super('Entry not found: $id');
  final String entryId;
}

/// インポートデータの形式が不正な場合。
final class InvalidImportFormatException extends DomainException {
  const InvalidImportFormatException(super.message);
}

/// 外部サービス（Sheets / AI）との通信が失敗した場合のドメイン表現。
/// インフラ例外は Application 層でこの型に変換して上位に伝える。
final class ExternalServiceException extends DomainException {
  const ExternalServiceException(super.message, {this.cause});
  final Object? cause;
}

/// 認証が必要な操作で未サインインだった場合。
final class UnauthenticatedException extends DomainException {
  const UnauthenticatedException()
      : super('User is not authenticated');
}
