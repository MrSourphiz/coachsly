import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:formeo/core/exceptions/app_exception.dart' as customError;
import 'package:formeo/core/constants/supabase_constants.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/domain/entities/exercise.dart';

class SupabaseDataSource {
  final SupabaseClient _client;

  SupabaseDataSource(this._client) {
    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      debugPrint('Auth state changed: event=${data.event}, session=$session');
    });
  }

  Future<AuthResponse> signUp(String email, String password, {String timezone = 'Europe/Moscow'}) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'timezone': timezone},
      );
      debugPrint('signUp response: user=${response.user?.id}, session=${response.session != null}');
      return response;
    } catch (error) {
      debugPrint('Ошибка в signUp: $error');
      final msg = error.toString();
      if (msg.contains('user_already_exists') ||
          msg.contains('User already registered') ||
          msg.contains('already been registered')) {
        // Не пытаемся залогинить автоматически — пароль может не совпадать,
        // а если совпадает — пользователь всё равно попадёт в онбординг заново.
        // Показываем понятную ошибку и направляем на экран входа.
        throw customError.AuthException(
            'Пользователь с таким email уже существует. Используйте вход.');
      }
      throw customError.AuthException('Ошибка регистрации: $error');
    }
  }

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(email: email, password: password);
    } catch (error) {
      throw customError.AuthException('Ошибка входа: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw customError.AuthException('Ошибка выхода: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final data = await _client.from(SupabaseConstants.usersTable).select();
      return data;
    } catch (error) {
      throw customError.DataException('Ошибка при получении пользователей: $error');
    }
  }

  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      final response = await _client.from(SupabaseConstants.usersTable).select().eq('id', userId).maybeSingle();
      if (response == null) {
        throw customError.AuthException('Пользователь не найден');
      }
      return response;
    } catch (error) {
      throw customError.AuthException('Ошибка получения данных пользователя: $error');
    }
  }

  Future<void> addUser(Map<String, dynamic> user) async {
    try {
      debugPrint('Текущая сессия перед addUser: ${_client.auth.currentSession}');
      debugPrint('Добавление пользователя: $user');
      await _client.from(SupabaseConstants.usersTable).insert(user);
      debugPrint('Пользователь успешно добавлен');
    } catch (error) {
      debugPrint('Ошибка в addUser: $error');
      throw customError.DataException('Ошибка при добавлении пользователя: $error');
    }
  }

  Future<void> updateUserAfterRegister({
    required String userId,
    String? token,
    required String timezone,
  }) async {
    try {
      debugPrint('updateUserAfterRegister: userId=$userId, timezone=$timezone');
      // role НЕ обновляем — устанавливается триггером handle_new_user на сервере
      await _client.from('users').update({
        'token': token,
        'timezone': timezone,
      }).eq('id', userId);
      debugPrint('updateUserAfterRegister: успешно');
    } catch (error) {
      debugPrint('Ошибка в updateUserAfterRegister: $error');
      throw customError.DataException('Ошибка при обновлении пользователя: $error');
    }
  }

  Future<bool> getFatsecretNeeded(String trainerId) async {
    try {
      final data = await _client
          .from('users')
          .select('fatsecret_needed')
          .eq('id', trainerId)
          .single();
      return data['fatsecret_needed'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setFatsecretNeeded(String trainerId, bool value) async {
    try {
      await _client
          .from('users')
          .update({'fatsecret_needed': value})
          .eq('id', trainerId);
    } catch (e) {
      throw customError.DataException('Не удалось обновить настройку Fatsecret: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getWorkoutPlans(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.workoutProgramsTable).select().eq('trainer_id', userId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить планы тренировок: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getQuickWorkoutPlans(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.quickWorkoutProgramsTable).select().eq('trainer_id', userId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить планы тренировок: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getClientsWorkoutPlans(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.clientWorkoutProgramsTable).select().eq('trainer_id', userId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить клиентские планы тренировок: $error');
    }
  }

  Future<Map<String, dynamic>> assignWorkoutPlan(Map<String, dynamic> plan) async {
    try {
      final response = await _client
          .from(SupabaseConstants.clientWorkoutProgramsTable)
          .insert(plan)
          .select()
          .single();
      return response;
    } catch (error) {
      throw customError.DataException('Не удалось назначить план тренировки: $error');
    }
  }

  Future<void> updateAssignedWorkoutPlan(String id, Map<String, dynamic> plan) async {
    try {
      await _client
          .from(SupabaseConstants.clientWorkoutProgramsTable)
          .update(plan)
          .eq('id', id);
    } catch (error) {
      throw customError.DataException('Не удалось обновить назначенный план тренировки: $error');
    }
  }

  Future<void> deleteAssignedWorkoutPlan(String id) async {
    try {
      await _client
          .from(SupabaseConstants.clientWorkoutProgramsTable)
          .delete()
          .eq('id', id);
    } catch (error) {
      throw customError.DataException('Не удалось удалить назначенный план тренировки: $error');
    }
  }

  Future<void> addWorkoutPlan(Map<String, dynamic> plan) async {
    try {
      await _client.from(SupabaseConstants.workoutProgramsTable).insert(plan);
    } catch (error) {
      throw customError.DataException('Не удалось добавить план тренировок: $error');
    }
  }

  Future<void> saveWorkoutPlan(String userId, WorkoutPlan plan) async {
    try {
      await _client.from(SupabaseConstants.workoutProgramsTable).insert({
        'name': plan.name,
        'type': plan.type,
        'duration': plan.duration,
        'days': plan.days.map((d) => d.toJson()).toList(),
        'trainer_id': userId,
      });
    } catch (error) {
      throw customError.DataException('Не удалось добавить план тренировок: $error');
    }
  }

  Future<void> changeWorkoutPlan(Map<String, dynamic> plan) async {
    try {
      await _client.from(SupabaseConstants.workoutProgramsTable).insert(plan);
    } catch (error) {
      throw customError.DataException('Не удалось добавить план тренировок: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getSchedules(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.schedulesTable).select().eq('trainer_id', userId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить расписание: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getClientBookings(String clientId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.schedulesTable)
          .select()
          .eq('client_id', clientId)
          .order('scheduled_at', ascending: false);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить тренировки клиента: $error');
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      await _client
          .from(SupabaseConstants.schedulesTable)
          .update({'booking_state': 'canceled'})
          .eq('id', bookingId);
    } catch (e) {
      throw customError.DataException('Не удалось отменить тренировку: $e');
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _client
          .from(SupabaseConstants.schedulesTable)
          .delete()
          .eq('id', scheduleId);
    } catch (e) {
      throw customError.DataException('Не удалось удалить тренировку: $e');
    }
  }

  /// Переносит тренировку: помечает старую как rescheduled,
  /// создаёт новую с новым временем.
  Future<void> rescheduleBooking({
    required String oldBookingId,
    required DateTime newScheduledAt,
    required String timezone,
    required String trainerId,
    required String clientId,
    required String sessionType,
    String? workoutPlanId,
    int? workoutDayNumber,
    String? description,
  }) async {
    try {
      await _client
          .from(SupabaseConstants.schedulesTable)
          .update({'booking_state': 'rescheduled'})
          .eq('id', oldBookingId);

      await _client
          .from(SupabaseConstants.schedulesTable)
          .insert({
        'scheduled_at': newScheduledAt.toUtc().toIso8601String(),
        'timezone': timezone,
        'trainer_id': trainerId,
        'client_id': clientId,
        'session_type': sessionType,
        'workout_plan_id': workoutPlanId,
        'workout_day_number': workoutDayNumber,
        'description': description ?? '',
      });
    } catch (e) {
      throw customError.DataException('Не удалось перенести тренировку: $e');
    }
  }

  Future<Set<String>> getPaidBookingIds(String trainerId) async {
    try {
      final rows = await _client
          .from(SupabaseConstants.paymentsTable)
          .select('booking_id')
          .eq('trainer_id', trainerId)
          .eq('status', 'paid');

      return {
        for (final row in rows)
          if (row['booking_id'] != null) row['booking_id'] as String,
      };
    } catch (e) {
      debugPrint('getPaidBookingIds error: $e');
      return {};
    }
  }

  Future<String> addSchedule(Map<String, dynamic> schedule) async {
    try {
      debugPrint('addSchedule payload: $schedule');
      final response = await _client
          .from(SupabaseConstants.schedulesTable)
          .insert(schedule)
          .select();

      if (response.isEmpty) {
        throw customError.DataException('Не удалось получить id новой записи');
      }

      final newRecord = response[0];
      return newRecord['id'] as String;
    } catch (error, stack) {
      debugPrint('addSchedule ERROR: $error');
      debugPrint('addSchedule STACK: $stack');
      throw customError.DataException('Не удалось добавить расписание: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTrainerClients(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.clientsTable).select().eq('trainer_id', userId);
      debugPrint('fetchTrainerClients DATA: $data');
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить список клиентов тренера: $error');
    }
  }

  Future<void> updateClientSessionType(String clientId, String sessionType) async {
    try {
      await _client
          .from(SupabaseConstants.clientsTable)
          .update({'default_session_type': sessionType})
          .eq('id', clientId);
    } catch (error) {
      throw customError.DataException('Не удалось обновить тип тренировки: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getTrainingDiaryEntries(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.trainingDiaryTable).select().eq('user_id', userId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить дневник тренировок: $error');
    }
  }

  Future<void> addTrainingDiaryEntry(Map<String, dynamic> entry) async {
    try {
      await _client.from(SupabaseConstants.trainingDiaryTable).insert(entry);
    } catch (error) {
      throw customError.DataException('Не удалось добавить дневник тренировок: $error');
    }
  }

  Future<Map<String, dynamic>?> checkAuthStatus() async {
    final session = _client.auth.currentSession;
    debugPrint('checkAuthStatus session: $session');
    if (session == null) {
      debugPrint('Сессия отсутствует');
      return null;
    }
    debugPrint('checkAuthStatus user: ${session.user.id}, email: ${session.user.email}');
    return {
      'id': session.user.id,
      'email': session.user.email,
      'token': session.accessToken,
    };
  }

  Future<Map<String, dynamic>?> getPaymentById(String paymentId) async {
    try {
      final data = await _client.from(SupabaseConstants.paymentsTable).select().eq('id', paymentId).single();
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить платёж: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getClientPayments(String clientId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.paymentsTable)
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить платежи клиента: $error');
    }
  }

  Future<String?> getReceiptSignedUrl(String storagePath) async {
    try {
      final response = await _client.storage
          .from('receipts')
          .createSignedUrl(storagePath, 60 * 60);
      return response;
    } catch (e) {
      throw customError.DataException('Не удалось получить ссылку на чек: $e');
    }
  }

  Future<Map<String, dynamic>?> getClientActiveSubscription(String clientId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.subscriptionsTable)
          .select()
          .eq('client_id', clientId)
          .eq('status', 'active')
          .maybeSingle();
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить абонемент клиента: $error');
    }
  }

  Future<Map<String, dynamic>?> getClientActiveBlock(String clientId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.trainingBlocksTable)
          .select()
          .eq('client_id', clientId)
          .eq('status', 'active')
          .maybeSingle();
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить блок клиента: $error');
    }
  }

  Future<Map<String, dynamic>?> getTrainerPaymentDetails(String trainerId) async {
    try {
      final data = await _client
          .from('trainer_payment_details')
          .select()
          .eq('trainer_id', trainerId)
          .maybeSingle();
      return data;
    } catch (e) {
      throw customError.DataException('Не удалось загрузить реквизиты: $e');
    }
  }

  Future<Map<String, dynamic>?> getPaymentByBookingId(String bookingId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.paymentsTable)
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить платёж по тренировке: $error');
    }
  }

  Future<Map<String, String?>> getReceiptPathsForBookings(List<String> bookingIds) async {
    if (bookingIds.isEmpty) return {};
    try {
      final rows = await _client
          .from(SupabaseConstants.paymentsTable)
          .select('booking_id, receipt_photo_url, created_at')
          .inFilter('booking_id', bookingIds)
          .order('created_at', ascending: false);

      // Берём самый свежий платёж на каждый booking_id (первый встреченный после сортировки desc)
      final Map<String, String?> result = {};
      for (final row in rows) {
        final bookingId = row['booking_id'] as String?;
        if (bookingId == null || result.containsKey(bookingId)) continue;
        result[bookingId] = row['receipt_photo_url'] as String?;
      }
      return result;
    } catch (e) {
      debugPrint('getReceiptPathsForBookings error: $e');
      return {};
    }
  }

  Future<void> saveTrainerPaymentDetails({
    required String trainerId,
    required String phoneNumber,
    String? preferredBank,
    double? singlePrice,
    double? blockPrice,
    double? subscriptionPrice,
    int? blockSessions,
    int? subscriptionDays,
  }) async {
    try {
      await _client.from('trainer_payment_details').upsert({
        'trainer_id': trainerId,
        'phone_number': phoneNumber,
        'preferred_bank': preferredBank,
        'single_price': singlePrice,
        'block_price': blockPrice,
        'subscription_price': subscriptionPrice,
        'block_sessions': blockSessions,
        'subscription_days': subscriptionDays,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'trainer_id');
    } catch (e) {
      throw customError.DataException('Не удалось сохранить реквизиты: $e');
    }
  }

  Future<void> updateTrainerProfile({
    required String trainerId,
    String? timezone,
    String? location,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (timezone != null) updates['timezone'] = timezone;
      if (location != null) updates['location'] = location;
      if (updates.isEmpty) return;

      await _client.from('users').update(updates).eq('id', trainerId);
    } catch (e) {
      throw customError.DataException('Не удалось обновить профиль: $e');
    }
  }

  /// Подписка на уведомления через postgres_changes (вместо .stream()).
  ///
  /// .stream() периодически пересоздаёт WebSocket и при закрытии
  /// бросает channelError → цикл переподключений и спам в консоли.
  /// postgres_changes восстанавливается прозрачно без ошибок.
  Stream<List<NotificationItem>> subscribeNotifications(String trainerId) async* {
    // 1. Начальная загрузка — сортируем по created_at desc
    final initial = await _client
        .from('notifications')
        .select()
        .eq('user_id', trainerId)
        .order('created_at', ascending: false);

    // Кэш: id → row
    final cache = <String, Map<String, dynamic>>{};
    for (final row in initial) {
      cache[row['id'] as String] = Map<String, dynamic>.from(row);
    }

    debugPrint('subscribeNotifications initial: ${cache.length}');
    yield _sortedNotifications(cache);

    // 2. Realtime channel — инкрементальные события
    final controller = StreamController<List<NotificationItem>>();

    final channel = _client
        .channel('notifications:user:$trainerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: trainerId,
      ),
      callback: (payload) {
        final eventType = payload.eventType;
        debugPrint('subscribeNotifications Realtime $eventType');

        if (eventType == PostgresChangeEvent.insert ||
            eventType == PostgresChangeEvent.update) {
          final row = Map<String, dynamic>.from(payload.newRecord);
          final id = row['id'] as String?;
          if (id != null) cache[id] = row;
        } else if (eventType == PostgresChangeEvent.delete) {
          final id = (payload.oldRecord['id'] ?? payload.newRecord['id']) as String?;
          if (id != null) cache.remove(id);
        }

        if (!controller.isClosed) {
          controller.add(_sortedNotifications(cache));
        }
      },
    ).subscribe();

    try {
      yield* controller.stream;
    } finally {
      await channel.unsubscribe();
      await controller.close();
    }
  }

  List<NotificationItem> _sortedNotifications(Map<String, Map<String, dynamic>> cache) {
    final list = cache.values.map((e) => NotificationItem.fromMap(e)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Подписка на расписание через настоящий Realtime channel.
  ///
  /// Почему не .stream():
  ///   .stream() — это polling-based snapshot с внутренним кэшем в SDK.
  ///   При DELETE он хранит удалённую запись в кэше и перезаписывает
  ///   оптимистичные обновления при следующем триггере (например INSERT).
  ///   postgres_changes получает инкрементальные события и ведёт кэш сам.

  Stream<List<Map<String, dynamic>>> subscribeSchedules(String trainerId) async* {
    // 1. Начальная загрузка через RPC — получаем rescheduled_to_at
    // и блочные поля (block_session_number / block_total_sessions)
    final initial = await _client
        .rpc('get_schedules_with_rescheduled', params: {'p_trainer_id': trainerId});

    final cache = <String, Map<String, dynamic>>{};
    for (final row in (initial as List)) {
      cache[row['id'] as String] = Map<String, dynamic>.from(row as Map);

      if (row['booking_state'] == 'rescheduled') {
        debugPrint('RESCHEDULED: id=${row['id']} rescheduled_to_at=${row['rescheduled_to_at']}');
      }
    }

    debugPrint('subscribeSchedules initial: ${cache.length}');
    yield List<Map<String, dynamic>>.from(cache.values);

    // 2. Realtime channel — только инкрементальные события
    // rescheduled_to_at и блочные поля (block_session_number,
    // block_total_sessions) при Realtime событии не обновляются (нет JOIN),
    // поэтому сохраняем их из кэша при INSERT/UPDATE
    final controller = StreamController<List<Map<String, dynamic>>>();

    final channel = _client
        .channel('bookings:trainer:$trainerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: SupabaseConstants.schedulesTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'trainer_id',
        value: trainerId,
      ),
      callback: (payload) {
        final eventType = payload.eventType;

        if (eventType == PostgresChangeEvent.insert ||
            eventType == PostgresChangeEvent.update) {
          final row = Map<String, dynamic>.from(payload.newRecord);
          final id = row['id'] as String?;
          if (id != null) {
            // Сохраняем поля, которые приходят только из RPC (JOIN) —
            // Realtime их не возвращает: rescheduled_to_at,
            // block_session_number, block_total_sessions
            final existing = cache[id];
            if (existing != null) {
              if (row['rescheduled_to_at'] == null) {
                row['rescheduled_to_at'] = existing['rescheduled_to_at'];
              }
              if (row['block_session_number'] == null) {
                row['block_session_number'] = existing['block_session_number'];
              }
              if (row['block_total_sessions'] == null) {
                row['block_total_sessions'] = existing['block_total_sessions'];
              }
            }
            cache[id] = row;
          }
        } else if (eventType == PostgresChangeEvent.delete) {
          final id = (payload.oldRecord['id'] ??
              payload.newRecord['id']) as String?;
          if (id != null) cache.remove(id);
        }

        if (!controller.isClosed) {
          controller.add(List<Map<String, dynamic>>.from(cache.values));
        }
      },
    )
        .subscribe();

    try {
      yield* controller.stream;
    } finally {
      await channel.unsubscribe();
      await controller.close();
    }
  }

  Future<void> sendSupportRequest({
    required String trainerId,
    required String message,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'support-request',
        body: {
          'trainer_id': trainerId,
          'message': message,
        },
      );

      debugPrint('Support response status: ${response.status}');
      debugPrint('Support response data: ${response.data}');

      if (response.status != 200) {
        throw Exception('Ошибка отправки: ${response.data}');
      }
    } catch (e) {
      debugPrint('sendSupportRequest error: $e');
      throw customError.DataException('Не удалось отправить обращение: $e');
    }
  }

  /// Полное удаление аккаунта тренера.
  ///
  /// Всё удаление выполняется на сервере в Edge Function `delete-account`
  /// (service role): очистка данных через RPC delete_trainer_data,
  /// файлов в Storage и учётки в auth.users. С клиента удалить
  /// пользователя из auth.users нельзя — нужен service role key.
  ///
  /// После успешного вызова сессия на сервере уже недействительна,
  /// локальный выход выполняет вызывающий код (AuthBloc → SignOut).
  Future<void> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      debugPrint('deleteAccount status: ${response.status}, data: ${response.data}');
      if (response.status != 200) {
        throw Exception(response.data);
      }
    } on FunctionException catch (e) {
      debugPrint('deleteAccount FunctionException: ${e.status} ${e.details}');
      throw customError.DataException('Не удалось удалить аккаунт: ${e.details ?? e.reasonPhrase}');
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      throw customError.DataException('Не удалось удалить аккаунт: $e');
    }
  }

  Future<List<Exercise>> fetchExercises({
    List<String>? categories,
    List<String>? muscles,
    List<String>? equipment,
    List<String>? difficulty,
  }) async {
    var query = _client.from('exercises_data').select();

    if (categories != null && categories.isNotEmpty) {
      query = query.inFilter('category', categories);
    }
    if (muscles != null && muscles.isNotEmpty) {
      query = query.inFilter('body_part', muscles);
    }
    if (equipment != null && equipment.isNotEmpty) {
      query = query.inFilter('equipment', equipment);
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      query = query.inFilter('difficulty_level', difficulty);
    }

    final response = await query;
    return response.map((e) => Exercise.fromJson(e)).toList();
  }

  Future<void> markAsRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  /// Получить одно уведомление по id — используется при точной навигации
  /// по тапу на push-уведомление (см. PushNotificationService).
  Future<NotificationItem?> getNotificationById(String id) async {
    try {
      final row = await _client
          .from('notifications')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return NotificationItem.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('Ошибка получения уведомления по id: $e');
      return null;
    }
  }

  Future<int> getSentNotificationsCount({
    required String trainerId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Один запрос вместо двух: выбираем все записи trainer_id == trainerId
      // (прямое поле) ИЛИ trainer_id через booking JOIN.
      // Фильтрацию по booking.trainer_id делаем на стороне клиента,
      // т.к. PostgREST не поддерживает OR между прямым и join-полем.
      // Прямой trainer_id покрывает записи без booking_id,
      // поэтому достаточно одного запроса с .eq('trainer_id', trainerId).
      final directCount = await _client
          .from('notification_queue')
          .select('id')
          .eq('trainer_id', trainerId)
          .inFilter('status', ['sent', 'completed'])
          .gte('last_attempt_at', from.toIso8601String())
          .lte('last_attempt_at', to.toIso8601String())
          .count(CountOption.exact);

      // Записи привязанные к booking другого тренера (edge case — обычно 0).
      // Если notification_queue всегда имеет trainer_id, второй запрос не нужен.
      return directCount.count;
    } catch (e) {
      debugPrint('getSentNotificationsCount error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getWeeklyPayments({
    required String trainerId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from('payments')
          .select()
          .eq('trainer_id', trainerId)
          .eq('status', 'completed')
          .gte('completed_at', from.toIso8601String())
          .lte('completed_at', to.toIso8601String());
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw customError.DataException('getWeeklyPayments error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getExpiredSubscriptions({
    required String trainerId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select()
          .eq('trainer_id', trainerId)
          .eq('status', 'expired')
          .gte('expired_at', from.toIso8601String())
          .lte('expired_at', to.toIso8601String());
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw customError.DataException('getExpiredSubscriptions error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getExhaustedBlocks({
    required String trainerId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from('training_blocks')
          .select()
          .eq('trainer_id', trainerId)
          .eq('status', 'exhausted')
          .gte('exhausted_at', from.toIso8601String())
          .lte('exhausted_at', to.toIso8601String());
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw customError.DataException('getExhaustedBlocks error: $e');
    }
  }

  Future<void> signInWithMagicLink(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'formeo://auth/callback',
      );
    } catch (e) {
      throw customError.DataException('Ошибка отправки ссылки: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'formeo://auth/callback',
      );
    } catch (e) {
      throw customError.DataException('Ошибка сброса пароля: $e');
    }
  }

  Future<void> saveDeviceToken({
    required String trainerId,
    required String token,
    required String platform,
  }) async {
    try {
      await _client.from('device_tokens').upsert({
        'trainer_id': trainerId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      throw customError.DataException('Не удалось сохранить токен: $e');
    }
  }

  Future<void> deleteDeviceToken({
    required String trainerId,
    required String token,
  }) async {
    try {
      await _client
          .from('device_tokens')
          .delete()
          .eq('trainer_id', trainerId)
          .eq('token', token);
    } catch (e) {
      throw customError.DataException('Не удалось удалить токен: $e');
    }
  }

  Future<bool> isOnboardingCompleted(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select('onboarding_completed')
          .eq('id', userId)
          .single();
      return data['onboarding_completed'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> completeOnboarding(String userId) async {
    try {
      await _client
          .from('users')
          .update({'onboarding_completed': true})
          .eq('id', userId);
    } catch (e) {
      throw customError.DataException('Ошибка завершения онбординга: $e');
    }
  }

  Session? getCurrentSession() {
    final session = _client.auth.currentSession;
    debugPrint('getCurrentSession: $session');
    return session;
  }

  Future<void> setRetentionEnabled(String userId, bool value) async {
    try {
      await _client
          .from('users')
          .update({'retention_enabled': value})
          .eq('id', userId);
    } catch (e) {
      throw customError.DataException('Ошибка сохранения retention_enabled: $e');
    }
  }

  Future<void> markRegistrationConsent(String userId, String consentAtIso) async {
    try {
      await _client.from('users').update({
        'terms_accepted_at': consentAtIso,
        'privacy_accepted_at': consentAtIso,
      }).eq('id', userId);
    } catch (e) {
      throw customError.DataException('Не удалось записать согласие с регистрации: $e');
    }
  }

  Future<void> startTrial(String userId) async {
    try {
      final now = DateTime.now().toUtc();
      final trialEnds = now.add(const Duration(days: 14));
      await _client.from('users').update({
        'trial_started_at': now.toIso8601String(),
        'trial_ends_at': trialEnds.toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      throw customError.DataException('Ошибка запуска триала: $e');
    }
  }

  Future<void> saveSubscription(String userId, String plan) async {
    try {
      await _client
          .from('users')
          .update({'subscription_plan': plan})
          .eq('id', userId);
    } catch (e) {
      throw customError.DataException('Ошибка сохранения подписки: $e');
    }
  }

  Future<void> saveSubscriptionAndStartTrial(String userId, String plan) async {
    try {
      final now = DateTime.now().toUtc();
      final trialEnds = now.add(const Duration(days: 14));
      await _client.from('users').update({
        'subscription_plan': plan,
        'trial_started_at': now.toIso8601String(),
        'trial_ends_at': trialEnds.toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      throw customError.DataException('Ошибка запуска триала: $e');
    }
  }

  /// Создаёт демо-клиента для тренера (если ещё не создан).
  /// Демо-клиент автоматически удаляется триггером БД, как только
  /// у тренера появляется первый реальный клиент в telegram_clients.
  Future<void> createDemoClient(String trainerId) async {
    try {
      await _client.rpc('create_demo_client', params: {'p_trainer_id': trainerId});
    } catch (e) {
      // Не критично для онбординга — просто логируем
      debugPrint('Не удалось создать демо-клиента: $e');
    }
  }

  /// Активная быстрая программа клиента вместе с полными данными плана —
  /// id и название плана, а также список упражнений с day_of_week и
  /// day_label, чтобы репозиторий мог собрать ActiveQuickPlanInfo
  /// (с реальными метками дней, не днями недели) без доп. запросов.
  Future<Map<String, dynamic>?> getActiveQuickPlanAssignment(String clientId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.assignedQuickPlansTable)
          .select('*, quick_workout_plans(id, name, quick_plan_exercises(day_of_week, day_label))')
          .eq('client_id', clientId)
          .eq('status', 'active')
          .maybeSingle();
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось получить активную программу клиента: $error');
    }
  }

  Future<Map<String, dynamic>> assignQuickWorkoutPlan({
    required String trainerId,
    required String clientId,
    required String quickPlanId,
    required DateTime startDate,
    required List<String> trainingDays,
    int? durationWeeks,
  }) async {
    try {
      final response = await _client.rpc('assign_quick_plan', params: {
        'p_trainer_id': trainerId,
        'p_client_id': clientId,
        'p_quick_plan_id': quickPlanId,
        'p_start_date': startDate.toIso8601String().split('T')[0],
        'p_training_days': trainingDays,
        'p_duration_weeks': durationWeeks,
      }).single();
      return response;
    } catch (error) {
      throw customError.DataException('Не удалось назначить программу клиенту: $error');
    }
  }

  /// Возвращает существующий журнал по booking_id (если тренировку уже
  /// открывали раньше) или создаёт новый — предотвращает дубликаты при
  /// повторном открытии карточки с дашборда.
  Future<Map<String, dynamic>> getOrCreateWorkoutLog({
    required String trainerId,
    required String clientId,
    String? bookingId,
    required String quickPlanId,
    required int dayOfWeek,
    required DateTime performedAt,
  }) async {
    try {
      if (bookingId != null) {
        final existing = await _client
            .from('workout_logs')
            .select()
            .eq('booking_id', bookingId)
            .maybeSingle();
        if (existing != null) return existing;
      }

      final response = await _client.from('workout_logs').insert({
        'trainer_id': trainerId,
        'client_id': clientId,
        'booking_id': bookingId,
        'quick_plan_id': quickPlanId,
        'day_of_week': dayOfWeek,
        'performed_at': performedAt.toIso8601String().split('T')[0],
        'status': 'in_progress',
      }).select().single();
      return response;
    } catch (error) {
      throw customError.DataException('Не удалось получить журнал тренировки: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getQuickPlanExercisesForDay(String quickPlanId, int dayOfWeek) async {
    try {
      final data = await _client
          .from('quick_plan_exercises')
          .select()
          .eq('quick_plan_id', quickPlanId)
          .eq('day_of_week', dayOfWeek)
          .order('exercise_order');
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить упражнения дня: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getWorkoutLogSets(String workoutLogId) async {
    try {
      final data = await _client
          .from('workout_log_sets')
          .select()
          .eq('workout_log_id', workoutLogId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить подходы: $error');
    }
  }

  Future<Map<String, dynamic>> upsertWorkoutLogSet(Map<String, dynamic> set) async {
    try {
      final response = await _client
          .from('workout_log_sets')
          .upsert(set, onConflict: 'workout_log_id,quick_plan_exercise_id,set_number')
          .select()
          .single();
      return response;
    } catch (error) {
      throw customError.DataException('Не удалось сохранить подход: $error');
    }
  }

  Future<void> completeWorkoutLog(String workoutLogId) async {
    try {
      await _client
          .from('workout_logs')
          .update({
        'status': 'completed',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', workoutLogId);
    } catch (error) {
      throw customError.DataException('Не удалось завершить тренировку: $error');
    }
  }

  /// История тренировок клиента с вложенными подходами, именами упражнений
  /// и меткой дня (day_label) — используется во вкладке "Тренировки"
  /// в client_details_screen.dart.
  Future<List<Map<String, dynamic>>> getClientWorkoutLogs(String clientId) async {
    try {
      final data = await _client
          .from('workout_logs')
          .select('*, workout_log_sets(*, quick_plan_exercises(custom_name, exercise_order, day_label))')
          .eq('client_id', clientId)
          .order('performed_at', ascending: false);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить историю тренировок: $error');
    }
  }

  /// Список клиентов, которым назначена эта быстрая программа (только активные
  /// назначения) — для отображения на экране просмотра программы.
  Future<List<Map<String, dynamic>>> getClientsForQuickPlan(String quickPlanId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.assignedQuickPlansTable)
          .select('start_date, training_days, telegram_clients(id, first_name, last_name)')
          .eq('quick_plan_id', quickPlanId)
          .eq('status', 'active')
          .order('start_date', ascending: false);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить клиентов программы: $error');
    }
  }

  /// Подписка на быстрые планы через Realtime — по тому же паттерну,
  /// что subscribeClients/subscribeSchedules: начальная загрузка +
  /// инкрементальные события, чтобы список обновлялся сразу после
  /// создания плана, без перезахода в приложение.
  Stream<List<Map<String, dynamic>>> subscribeQuickWorkoutPlans(String trainerId) async* {
    final initial = await _client
        .from(SupabaseConstants.quickWorkoutProgramsTable)
        .select()
        .eq('trainer_id', trainerId);

    final cache = <String, Map<String, dynamic>>{};
    for (final row in initial) {
      cache[row['id'] as String] = Map<String, dynamic>.from(row);
    }

    debugPrint('subscribeQuickWorkoutPlans initial: ${cache.length}');
    yield List<Map<String, dynamic>>.from(cache.values);

    final controller = StreamController<List<Map<String, dynamic>>>();

    final channel = _client
        .channel('quick_workout_plans:trainer:$trainerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: SupabaseConstants.quickWorkoutProgramsTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'trainer_id',
        value: trainerId,
      ),
      callback: (payload) {
        final eventType = payload.eventType;

        if (eventType == PostgresChangeEvent.insert ||
            eventType == PostgresChangeEvent.update) {
          final row = Map<String, dynamic>.from(payload.newRecord);
          final id = row['id'] as String?;
          if (id != null) cache[id] = row;
        } else if (eventType == PostgresChangeEvent.delete) {
          final id = (payload.oldRecord['id'] ?? payload.newRecord['id']) as String?;
          if (id != null) cache.remove(id);
        }

        if (!controller.isClosed) {
          controller.add(List<Map<String, dynamic>>.from(cache.values));
        }
      },
    ).subscribe();

    try {
      yield* controller.stream;
    } finally {
      await channel.unsubscribe();
      await controller.close();
    }
  }
}