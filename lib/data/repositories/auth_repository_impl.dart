import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

final logger = Logger();
const _storage = FlutterSecureStorage();
const _keyRole     = 'cached_user_role';
const _keyTimezone = 'cached_user_timezone';

// Ключ, под которым register_screen.dart временно кэширует факт согласия
// с офертой/политикой при регистрации. Значения должны совпадать дословно —
// см. kPendingConsentKey в register_screen.dart.
const _kPendingConsentKey = 'pending_registration_consent_at';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  String _mapAuthError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'Неверный email или пароль';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email не подтверждён. Проверьте почту';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'Пользователь с таким email уже существует';
    }
    if (msg.contains('network') || msg.contains('socket') ||
        msg.contains('connection')) {
      return 'Нет подключения к интернету';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Слишком много попыток. Подождите немного';
    }
    if (msg.contains('rate limit') ||
        msg.contains('over_email_send_rate_limit') ||
        msg.contains('too many requests')) {
      return 'Слишком много попыток. Попробуйте через несколько минут';
    }
    return 'Произошла ошибка. Попробуйте ещё раз';
  }

  /// Загружает userData с одним retry через 1.5с.
  /// Нужно для случая когда триггер handle_new_user ещё не завершился
  /// к моменту первого checkAuthStatus после подтверждения email.
  Future<Map<String, dynamic>> _getUserDataWithRetry(String userId) async {
    try {
      final data = await _dataSource.getUserData(userId);
      if (data.isEmpty) throw AuthException('Данные пользователя не найдены');
      return data;
    } catch (e) {
      debugPrint('checkAuthStatus: первая попытка getUserData упала, retry через 1.5с: $e');
      await Future.delayed(const Duration(milliseconds: 1500));
      final data = await _dataSource.getUserData(userId);
      if (data.isEmpty) throw AuthException('Данные пользователя не найдены');
      return data;
    }
  }

  /// Если при регистрации на этом устройстве осталось несписанное согласие
  /// с офертой/политикой — записывает его в БД сейчас. К этому моменту
  /// сессия уже точно активна и public.users уже существует — в отличие
  /// от момента самой регистрации, когда мог требоваться подтверждение
  /// email и записи ещё могло не быть (см. register_screen.dart).
  Future<void> _flushPendingRegistrationConsent(String userId) async {
    final pendingConsentAt = await _storage.read(key: _kPendingConsentKey);
    if (pendingConsentAt == null) return;

    try {
      await _dataSource.markRegistrationConsent(userId, pendingConsentAt);
      await _storage.delete(key: _kPendingConsentKey);
    } catch (e) {
      logger.w('checkAuthStatus: не удалось записать согласие с регистрации: $e');
      // Ключ не удаляем — попробуем записать при следующем вызове.
    }
  }

  @override
  Future<User?> checkAuthStatus() async {
    final authData = await _dataSource.checkAuthStatus();
    if (authData == null) return null;

    final userId = authData['id'] as String;
    final email  = authData['email'] as String;

    Map<String, dynamic> userData;
    try {
      userData = await _getUserDataWithRetry(userId);
      // Кэшируем роль и timezone локально для fallback при потере сети
      await _storage.write(key: _keyRole,     value: userData['role'] as String? ?? 'trainer');
      await _storage.write(key: _keyTimezone, value: userData['timezone'] as String? ?? 'Europe/Moscow');
      // Дописываем согласие с регистрации, если оно ещё не попало в БД
      await _flushPendingRegistrationConsent(userId);
    } catch (e) {
      // Оба запроса упали — запись в public.users отсутствует или нет сети.
      logger.w('checkAuthStatus: getUserData упал дважды: $e');

      final cachedRole     = await _storage.read(key: _keyRole);
      final cachedTimezone = await _storage.read(key: _keyTimezone) ?? 'Europe/Moscow';

      // Кэша нет — пользователь не регистрировался на этом устройстве → /auth
      if (cachedRole == null) {
        debugPrint('checkAuthStatus: кэша нет → возвращаем null');
        return null;
      }

      // Кэш есть, но записи в public.users нет — триггер не сработал
      // (пользователь зарегистрирован до добавления триггера).
      // Создаём запись прямо сейчас пока сессия валидна.
      debugPrint('checkAuthStatus: кэш есть, записи нет → создаём в public.users');
      try {
        await _dataSource.addUser({
          'id':                   userId,
          'email':                email,
          'role':                 cachedRole,
          'timezone':             cachedTimezone,
          'onboarding_completed': true, // пользователь уже регистрировался ранее
        });
        debugPrint('checkAuthStatus: запись создана, повторяем getUserData');
        userData = await _dataSource.getUserData(userId);
        await _storage.write(key: _keyRole,     value: userData['role'] as String? ?? cachedRole);
        await _storage.write(key: _keyTimezone, value: userData['timezone'] as String? ?? cachedTimezone);
        await _flushPendingRegistrationConsent(userId);
      } catch (createError) {
        // Если getUserData упал дважды И addUser тоже упал —
        // пользователя нет в auth.users (удалён из Supabase).
        // При отсутствии сети getUserData бы прошёл (есть кэш сессии),
        // значит это не сетевая ошибка — разлогиниваем.
        debugPrint('checkAuthStatus: addUser упал: $createError → signOut');
        try { await _dataSource.signOut(); } catch (_) {}
        await _storage.delete(key: _keyRole);
        await _storage.delete(key: _keyTimezone);
        return null;
      }
    }

    String deviceTimezone = userData['timezone'] as String? ?? 'Europe/Moscow';
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      deviceTimezone = timezoneInfo.identifier;
      final savedTimezone = userData['timezone'] as String? ?? 'Europe/Moscow';
      if (deviceTimezone != savedTimezone) {
        await _dataSource.updateTrainerProfile(
          trainerId: userId,
          timezone: deviceTimezone,
        );
      }
    } catch (e) {
      logger.w('checkAuthStatus: не удалось обновить timezone: $e');
    }

    return User(
      id:       userId,
      email:    email,
      token:    userData['token'],
      role:     userData['role'],
      timezone: deviceTimezone,
      location: userData['location'],
      retentionEnabled: userData['retention_enabled'] as bool? ?? false,
      fatsecretNeeded: userData['fatsecret_needed'] as bool? ?? false,
      subscriptionPlan: userData['subscription_plan'] as String?,
      trialStartedAt: userData['trial_started_at'] != null
          ? DateTime.parse(userData['trial_started_at'] as String)
          : null,
      trialEndsAt: userData['trial_ends_at'] != null
          ? DateTime.parse(userData['trial_ends_at'] as String)
          : null,
      subscriptionStatus: userData['subscription_status'] as String? ?? 'trial',
      nextBillingAt: userData['next_billing_at'] != null
          ? DateTime.parse(userData['next_billing_at'] as String)
          : null,
      autoRenew: userData['auto_renew'] as bool? ?? true,
    );
  }

  @override
  Future<User> register(String email, String password, String role, String timezone) async {
    try {
      if (!['trainer', 'client'].contains(role)) {
        logger.w('Недопустимая роль: $role');
        throw AuthException('Роль должна быть "trainer" или "client"');
      }

      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final userTimezone = timezoneInfo.identifier;

      debugPrint('Шаг 1: signUp вызван');
      // Передаём timezone в raw_user_meta_data — триггер handle_new_user
      // прочитает его и сразу запишет правильное значение в public.users.
      final authResponse = await _dataSource.signUp(
        email,
        password,
        timezone: userTimezone,
      );
      debugPrint('Шаг 2: signUp завершён, user=${authResponse.user?.id}');

      if (authResponse.user == null) {
        logger.w('Пользователь не создан');
        throw AuthException('Пользователь не создан');
      }

      final userId    = authResponse.user!.id;
      final userToken = authResponse.session?.accessToken;

      // Кэшируем роль и timezone — понадобятся после подтверждения email
      await _storage.write(key: _keyRole,     value: role);
      await _storage.write(key: _keyTimezone, value: userTimezone);

      // Если сессия уже активна прямо сейчас (email confirmation отключено
      // в проекте) — пишем согласие сразу. Если нет — оно уже закэшировано
      // в register_screen.dart и попадёт в БД при первом checkAuthStatus()
      // после подтверждения email (см. _flushPendingRegistrationConsent).
      if (authResponse.session != null) {
        await _flushPendingRegistrationConsent(userId);
      }

      debugPrint('Регистрация завершена, ожидаем подтверждения email');

      // Новый пользователь — subscriptionStatus и nextBillingAt здесь
      // намеренно НЕ передаём, дефолт 'trial'/null конструктора корректен.
      return User(id: userId, email: email, token: userToken, role: role, timezone: userTimezone);
    } catch (e) {
      logger.e('Ошибка регистрации:', error: e);
      if (e is AuthException) rethrow;
      throw AuthException(_mapAuthError(e));
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final authResponse = await _dataSource.signIn(email, password);
      if (authResponse.user == null) {
        logger.w('Пользователь не найден');
        throw AuthException('Неверный email или пароль');
      }
      final userId   = authResponse.user!.id;
      final userData = await _dataSource.getUserData(userId);
      if (userData.isEmpty) {
        logger.w('Данные пользователя не найдены');
        throw AuthException('Произошла ошибка. Попробуйте ещё раз');
      }

      // Кэшируем роль при каждом успешном входе
      await _storage.write(key: _keyRole,     value: userData['role'] as String? ?? 'trainer');
      await _storage.write(key: _keyTimezone, value: userData['timezone'] as String? ?? 'Europe/Moscow');

      // На случай если пользователь зарегистрировался, но приложение
      // закрылось до первого checkAuthStatus — дописываем согласие и здесь.
      await _flushPendingRegistrationConsent(userId);

      return User(
        id:       userId,
        email:    email,
        token:    userData['token'],
        role:     userData['role'],
        timezone: userData['timezone'],
        location: userData['location'],
        retentionEnabled: userData['retention_enabled'] as bool? ?? false,
        fatsecretNeeded: userData['fatsecret_needed'] as bool? ?? false,
        subscriptionPlan: userData['subscription_plan'] as String?,
        trialStartedAt: userData['trial_started_at'] != null
            ? DateTime.parse(userData['trial_started_at'] as String)
            : null,
        trialEndsAt: userData['trial_ends_at'] != null
            ? DateTime.parse(userData['trial_ends_at'] as String)
            : null,
        subscriptionStatus: userData['subscription_status'] as String? ?? 'trial',
        nextBillingAt: userData['next_billing_at'] != null
            ? DateTime.parse(userData['next_billing_at'] as String)
            : null,
        autoRenew: userData['auto_renew'] as bool? ?? true,
      );
    } catch (e) {
      logger.e('Ошибка входа:', error: e);
      if (e is AuthException) rethrow;
      throw AuthException(_mapAuthError(e));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dataSource.signOut();
      // Очищаем кэш роли при выходе
      await _storage.delete(key: _keyRole);
      await _storage.delete(key: _keyTimezone);
    } catch (e) {
      logger.e('Ошибка при выходе:', error: e);
      throw AuthException('Произошла ошибка при выходе');
    }
  }
}
