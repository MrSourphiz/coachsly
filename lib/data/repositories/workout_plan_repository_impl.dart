import 'package:logger/logger.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/entities/assigned_workout_plan.dart';
import 'package:formeo/domain/entities/assigned_quick_plan.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';

final logger = Logger();

//преобразуем данные из JSON в сущности и наоборот
class WorkoutPlanRepositoryImpl implements WorkoutPlanRepository {
  final SupabaseDataSource _dataSource;

  WorkoutPlanRepositoryImpl(this._dataSource);

  @override
  Future<List<WorkoutPlan>> getWorkoutPlans(String userId) async {
    final response = await _dataSource.getWorkoutPlans(userId);
    return response.map((json) => WorkoutPlan.fromJson(json)).toList();
  }

  @override
  Future<List<QuickWorkoutPlan>> getQuickWorkoutPlans(String userId) async {
    final response = await _dataSource.getQuickWorkoutPlans(userId);
    return response.map((json) => QuickWorkoutPlan.fromJson(json)).toList();
  }

  @override
  Future<List<AssignedWorkoutProgram>> getClientsWorkoutPlans(String userId) async {
    final response = await _dataSource.getClientsWorkoutPlans(userId);
    return response.map((json) => AssignedWorkoutProgram.fromJson(json)).toList();
  }

  @override
  Future<AssignedWorkoutProgram> assignWorkoutPlan(AssignedWorkoutProgram plan) async {
    try {
      // Преобразуем сущность в Map для Supabase
      final planMap = {
        'trainer_id': plan.trainerId,
        'client_id': plan.clientId,
        'workout_program_id': plan.workoutProgramId,
        'start_date': plan.startDate.toIso8601String().split('T')[0],
        'training_days': plan.trainingDays,
        'duration_weeks': plan.durationWeeks,
        'type': plan.type,
        // created_at будет автоматически добавлен Supabase (default now())
      };

      // Если id уже есть (например, при обновлении), передаем его
      if (plan.id.isNotEmpty) {
        planMap['id'] = plan.id;
      }

      // Отправляем данные в Supabase и получаем созданную запись
      final response = await _dataSource.assignWorkoutPlan(planMap);

      // Преобразуем ответ обратно в сущность
      return AssignedWorkoutProgram.fromJson(response);
    } catch (e) {
      logger.e('Ошибка при назначении плана тренировок:', error: e);
      throw DataException('Ошибка при назначении плана тренировок: $e');
    }
  }

  @override
  Future<void> updateAssignedWorkoutPlan(AssignedWorkoutProgram plan) async {
    try {
      // Преобразуем сущность в Map для обновления
      final planMap = {
        'client_id': plan.clientId,
        'workout_program_id': plan.workoutProgramId,
        'start_date': plan.startDate.toIso8601String().split('T')[0],
        'training_days': plan.trainingDays,
        'duration_weeks': plan.durationWeeks,
        'type': plan.type,
      };

      await _dataSource.updateAssignedWorkoutPlan(plan.id, planMap);
    } catch (e) {
      logger.e('Ошибка при обновлении назначенного плана тренировок:', error: e);
      throw DataException('Ошибка при обновлении назначенного плана тренировок: $e');
    }
  }

  @override
  Future<void> deleteAssignedWorkoutPlan(String planId) async {
    try {
      await _dataSource.deleteAssignedWorkoutPlan(planId);
    } catch (e) {
      logger.e('Ошибка при удалении назначенного плана тренировок:', error: e);
      throw DataException('Ошибка при удалении назначенного плана тренировок: $e');
    }
  }

  @override
  Future<void> createWorkoutPlan(String userId, WorkoutPlan plan) async {
    try {
      await _dataSource.saveWorkoutPlan(userId, plan);
    } catch (e) {
      // Обрабатываем возможные ошибки
      logger.e('Ошибка при добавлении плана тренировок:', error:e );
      throw DataException('Ошибка при добавлении плана тренировок: $e');
    }
  }

  @override
  Future<void> changeWorkoutPlan(WorkoutPlan plan) async {
    try {
      // Вызываем метод addWorkoutPlan из SupabaseDataSource, передавая данные плана
      await _dataSource.changeWorkoutPlan(plan.toJson());
    } catch (e) {
      // Обрабатываем возможные ошибки
      logger.e('Ошибка при изменении плана тренировок:', error:e );
      throw DataException('Ошибка при изменении плана тренировок: $e');
    }
  }

  @override
  Future<String?> getActiveQuickPlanName(String clientId) async {
    try {
      final data = await _dataSource.getActiveQuickPlanAssignment(clientId);
      if (data == null) return null;
      final planData = data['quick_workout_plans'];
      if (planData is Map && planData['name'] != null) return planData['name'] as String;
      return null;
    } catch (e) {
      // Не критично для UI — просто не покажем предупреждение, не блокируем назначение
      logger.e('Ошибка при получении активной программы клиента:', error: e);
      return null;
    }
  }

  @override
  Future<ActiveQuickPlanInfo?> getActiveQuickPlanInfo(String clientId) async {
    try {
      final data = await _dataSource.getActiveQuickPlanAssignment(clientId);
      if (data == null) return null;

      final planData = data['quick_workout_plans'];
      if (planData is! Map) return null;

      final planId = planData['id'] as String?;
      final planName = planData['name'] as String?;
      if (planId == null || planName == null) return null;

      final exercisesRaw = planData['quick_plan_exercises'];
      final days = <int>{};
      final labels = <int, String>{};
      if (exercisesRaw is List) {
        for (final e in exercisesRaw) {
          final map = e as Map;
          final d = map['day_of_week'];
          if (d is int) {
            days.add(d);
            final label = map['day_label'] as String?;
            if (!labels.containsKey(d)) {
              labels[d] = (label != null && label.trim().isNotEmpty) ? label : 'День ${d + 1}';
            }
          }
        }
      }
      final sortedDays = days.toList()..sort();

      return ActiveQuickPlanInfo(
        quickPlanId: planId,
        planName: planName,
        dayNumbers: sortedDays,
        dayLabels: labels,
      );
    } catch (e) {
      // Не критично для UI брони — просто не покажем дропдаун дня программы
      logger.e('Ошибка при получении активной программы клиента:', error: e);
      return null;
    }
  }

  @override
  Future<AssignedQuickPlan> assignQuickWorkoutPlan(AssignedQuickPlan assignment) async {
    try {
      final response = await _dataSource.assignQuickWorkoutPlan(
        trainerId: assignment.trainerId,
        clientId: assignment.clientId,
        quickPlanId: assignment.quickPlanId,
        startDate: assignment.startDate,
        trainingDays: assignment.trainingDays,
        durationWeeks: assignment.durationWeeks,
      );
      return AssignedQuickPlan.fromJson(response);
    } catch (e) {
      logger.e('Ошибка при назначении быстрой программы:', error: e);
      throw DataException('Ошибка при назначении быстрой программы: $e');
    }
  }

  @override
  Future<List<AssignedPlanClient>> getClientsForQuickPlan(String quickPlanId) async {
    try {
      final rows = await _dataSource.getClientsForQuickPlan(quickPlanId);
      return rows.map((row) {
        final clientData = row['telegram_clients'] as Map?;
        final firstName = clientData?['first_name'] as String? ?? '';
        final lastName = clientData?['last_name'] as String?;
        return AssignedPlanClient(
          clientId: clientData?['id'] as String? ?? '',
          clientName: '$firstName ${lastName ?? ''}'.trim(),
          startDate: DateTime.parse(row['start_date'] as String),
          trainingDays: List<String>.from(row['training_days'] as List),
        );
      }).where((c) => c.clientId.isNotEmpty).toList();
    } catch (e) {
      logger.e('Ошибка при получении клиентов программы:', error: e);
      return []; // не критично для UI — просто не покажем список, не блокируем экран
    }
  }
}
