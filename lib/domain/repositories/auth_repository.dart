import 'package:coachsly/domain/entities/user.dart';

abstract class AuthRepository {
  /// Проверяет текущий статус аутентификации пользователя.
  /// Возвращает [User] если пользователь аутентифицирован, иначе null.
  Future<User?> checkAuthStatus();

  /// Регистрирует нового пользователя с указанным email, паролем и ролью.
  /// [email] - адрес электронной почты.
  /// [password] - пароль пользователя.
  /// [role] - роль пользователя (например, 'trainer' или 'client').
  /// Возвращает созданного [User].
  Future<User> register(String email, String password, String role, String timezone);

  /// Логинит пользователя с указанным email и паролем.
  /// [email] - адрес электронной почты.
  /// [password] - пароль пользователя.
  /// Возвращает залогиненного [User].
  Future<User> login(String email, String password);

  /// Выход из текущего пользователя.
  Future<void> logout();
}