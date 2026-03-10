import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coachsly/core/exceptions/app_exception.dart' as customError;
import 'package:coachsly/core/constants/supabase_constants.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/entities/notification.dart';
import 'package:coachsly/domain/entities/exercise.dart';

class SupabaseDataSource {
  final SupabaseClient _client;

  SupabaseDataSource(this._client) {
    // Подписка на изменения состояния аутентификации
    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      print('Auth state changed: event=${data.event}, session=$session');
    });
  }

  Future<AuthResponse> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(email: email, password: password);
      print('signUp response: user=${response.user?.id}, session=${response.session != null}');
      if (response.session == null) {
        print('Сессия отсутствует в signUp response. Проверяем текущую сессию...');
        final currentSession = _client.auth.currentSession;
        print('Текущая сессия: $currentSession');
      } else {
        print('Сессия создана: accessToken=${response.session!.accessToken}, refreshToken=${response.session!.refreshToken}');
      }
      return response;
    } catch (error) {
      print('Ошибка в signUp: $error');
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
      print('Текущая сессия перед addUser: ${_client.auth.currentSession}');
      print('Добавление пользователя: $user');
      await _client.from(SupabaseConstants.usersTable).insert(user);
      print('Пользователь успешно добавлен');
    } catch (error) {
      print('Ошибка в addUser: $error');
      throw customError.DataException('Ошибка при добавлении пользователя: $error');
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

  // Удаление назначенного плана
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

//  Future<void> addSchedule(Map<String, dynamic> schedule) async {
//    try {
//      await _client.from(SupabaseConstants.schedulesTable).insert(schedule);
//    } catch (error) {
//      throw customError.DataException('Не удалось добавить расписание: $error');
//    }
//  }
  Future<String> addSchedule(Map<String, dynamic> schedule) async {
    try {
      final response = await _client
          .from(SupabaseConstants.schedulesTable)
          .insert(schedule)
          .select(); // возвращает вставленную запись

      if (response == null || response.isEmpty) {
        throw customError.DataException('Не удалось получить id новой записи');
      }

      final newRecord = response[0];
      return newRecord['id'] as String; // возвращаем id вставленной записи
    } catch (error) {
      throw customError.DataException('Не удалось добавить расписание: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTrainerClients(String userId) async {
    try {
      final data = await _client.from(SupabaseConstants.clientsTable).select().eq('trainer_id', userId);
      return data;
    } catch (error) {
      throw customError.DataException('Не удалось загрузить список клиентов тренера: $error');
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
    print('checkAuthStatus session: $session');
    if (session == null || session.user == null) {
      print('Сессия или пользователь отсутствуют');
      print('Текущая сессия: ${_client.auth.currentSession}');
      return null;
    }
    print('checkAuthStatus user: ${session.user!.id}, email: ${session.user!.email}');
    return {
      'id': session.user!.id,
      'email': session.user!.email,
      'token': session.accessToken,
    };
  }

  // подписка на уведомления
  // Подписка на уведомления по конкретному тренеру
  Stream<List<NotificationItem>> subscribeNotifications(String trainerId) async* {
    // 1️⃣ Получаем текущие уведомления
    final initial = await _client
        .from('notifications')
        .select()
        .eq('user_id', trainerId)
        .order('created_at', ascending: false);

    yield initial != null
        ? List<Map<String, dynamic>>.from(initial)
        .map((e) => NotificationItem.fromMap(e))
        .toList()
        : [];

    // 2️⃣ Подписка на изменения через Realtime
    yield* _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => List<Map<String, dynamic>>.from(rows)
        .map((e) => NotificationItem.fromMap(e))
        .toList());
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



  // Новый метод для получения текущей сессии
  Session? getCurrentSession() {
    final session = _client.auth.currentSession;
    print('getCurrentSession: $session');
    return session;
  }
}
