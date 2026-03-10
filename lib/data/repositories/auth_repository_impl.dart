import 'package:logger/logger.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/user.dart';
import 'package:coachsly/domain/repositories/auth_repository.dart';
import 'package:coachsly/data/sources/supabase_data_source.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

final logger = Logger();

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Future<User?> checkAuthStatus() async {
    try {
      final authData = await _dataSource.checkAuthStatus();
      if (authData == null) {
        return null;
      }

      final userId = authData['id'] as String;
      final userData = await _dataSource.getUserData(userId);
      if (userData.isEmpty) {
        logger.w('Данные пользователя не найдены');
        throw AuthException('Данные пользователя не найдены');
      }

      return User(
        id: userId,
        email: authData['email'] as String,
        token: userData['token'],
        role: userData['role'],
        timezone: userData['timezone'],
      );
    } catch (e) {
      logger.e('Ошибка проверки статуса авторизации:', error:e );
      throw AuthException('Ошибка проверки статуса авторизации: $e');
    }
  }

  @override
  Future<User> register(String email, String password, String role, String timezone) async {
    try {
      if (!['trainer', 'client'].contains(role)) {
        logger.w('Недопустимая роль: $role');
        throw AuthException('Роль должна быть "trainer" или "client"');
      }
      final authResponse = await _dataSource.signUp(email, password);
      if (authResponse.user == null) {
        logger.w('Пользователь не создан');
        throw AuthException('Пользователь не создан');
      }
      final userId = authResponse.user!.id;
      final userToken = authResponse.session?.accessToken;

      final userTimezone = await FlutterTimezone.getLocalTimezone();

      final userData = {
        'id': userId,
        'email': email,
        'token': userToken,
        'role': role,
        'timezone': userTimezone,
      };
      print('Отправка userData: $userData');
      print('Текущая сессия перед addUser: ${_dataSource.getCurrentSession()}');
      await _dataSource.addUser(userData);
      print('Пользователь успешно добавлен');
      print('Текущая сессия после addUser: ${_dataSource.getCurrentSession()}');

      return User(id: userId, email: email, token: userToken, role: role, timezone: timezone);
    } catch (e) {
      logger.e('Ошибка регистрации:', error: e);
      throw AuthException('Ошибка регистрации: $e');
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final authResponse = await _dataSource.signIn(email, password);
      if (authResponse.user == null) {
        logger.w('Пользователь не найден');
        throw AuthException('Пользователь не найден');
      }
      final userId = authResponse.user!.id;
      final userData = await _dataSource.getUserData(userId);
      if (userData.isEmpty) {
        logger.w('Данные пользователя не найдены');
        throw AuthException('Данные пользователя не найдены');
      }

      return User(id: userId, email: email, token: userData['token'], role: userData['role'], timezone: userData['timezone']);
    } catch (e) {
      logger.e('Ошибка входа:', error:e );
      throw AuthException('Ошибка входа: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dataSource.signOut();
    } catch (e) {
      logger.e('Ошибка при выходе:', error:e );
      throw AuthException('Ошибка при выходе: $e');
    }
  }
}
