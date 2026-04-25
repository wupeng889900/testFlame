class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  ApiException(this.message, {this.statusCode, this.error});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class AuthException extends ApiException {
  AuthException(String message) : super(message, statusCode: 401);
}

class RateLimitException extends ApiException {
  RateLimitException(String message) : super(message, statusCode: 429);
}

class ServerException extends ApiException {
  ServerException(String message, int? statusCode) : super(message, statusCode: statusCode);
}
