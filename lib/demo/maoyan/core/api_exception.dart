class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  ApiException(this.message, {this.statusCode, this.error});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException(super.message);
}

class AuthException extends ApiException {
  AuthException(super.message) : super(statusCode: 401);
}

class RateLimitException extends ApiException {
  RateLimitException(super.message) : super(statusCode: 429);
}

class ServerException extends ApiException {
  ServerException(super.message, int? statusCode)
    : super(statusCode: statusCode);
}
