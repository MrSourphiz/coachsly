import 'package:logger/logger.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/data/sources/supabase_data_source.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/domain/entities/assigned_workout_plan.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';

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
}