abstract class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(String message) : super(message);
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class DataException extends AppException {
  DataException(String message) : super(message);
}

class ServerException extends AppException {
  ServerException(String message) : super(message);
}

class RateLimitException implements Exception{}
