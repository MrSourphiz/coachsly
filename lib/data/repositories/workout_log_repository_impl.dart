import 'package:logger/logger.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/entities/workout_log.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/repositories/workout_log_repository.dart';

final _workoutLogLogger = Logger();

class WorkoutLogRepositoryImpl implements WorkoutLogRepository {
  final SupabaseDataSource _dataSource;

  WorkoutLogRepositoryImpl(this._dataSource);

  @override
  Future<WorkoutLog> getOrCreateWorkoutLog({
    required String trainerId,
    required String clientId,
    String? bookingId,
    required String quickPlanId,
    required int dayOfWeek,
    required DateTime performedAt,
  }) async {
    try {
      final response = await _dataSource.getOrCreateWorkoutLog(
        trainerId: trainerId,
        clientId: clientId,
        bookingId: bookingId,
        quickPlanId: quickPlanId,
        dayOfWeek: dayOfWeek,
        performedAt: performedAt,
      );
      return WorkoutLog.fromJson(response);
    } catch (e) {
      _workoutLogLogger.e('Ошибка при получении журнала тренировки:', error: e);
      throw DataException('Ошибка при получении журнала тренировки: $e');
    }
  }

  @override
  Future<List<QuickPlanExercise>> getPlanExercisesForDay(String quickPlanId, int dayOfWeek) async {
    try {
      final response = await _dataSource.getQuickPlanExercisesForDay(quickPlanId, dayOfWeek);
      return response.map((json) => QuickPlanExercise.fromJson(json)).toList();
    } catch (e) {
      _workoutLogLogger.e('Ошибка при получении упражнений дня:', error: e);
      throw DataException('Ошибка при получении упражнений дня: $e');
    }
  }

  @override
  Future<List<WorkoutLogSet>> getWorkoutLogSets(String workoutLogId) async {
    try {
      final response = await _dataSource.getWorkoutLogSets(workoutLogId);
      return response.map((json) => WorkoutLogSet.fromJson(json)).toList();
    } catch (e) {
      _workoutLogLogger.e('Ошибка при получении подходов:', error: e);
      throw DataException('Ошибка при получении подходов: $e');
    }
  }

  @override
  Future<WorkoutLogSet> upsertWorkoutLogSet(WorkoutLogSet set) async {
    try {
      final response = await _dataSource.upsertWorkoutLogSet(set.toJson());
      return WorkoutLogSet.fromJson(response);
    } catch (e) {
      _workoutLogLogger.e('Ошибка при сохранении подхода:', error: e);
      throw DataException('Ошибка при сохранении подхода: $e');
    }
  }

  @override
  Future<void> completeWorkoutLog(String workoutLogId) async {
    try {
      await _dataSource.completeWorkoutLog(workoutLogId);
    } catch (e) {
      _workoutLogLogger.e('Ошибка при завершении тренировки:', error: e);
      throw DataException('Ошибка при завершении тренировки: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getClientWorkoutLogs(String clientId) async {
    try {
      return await _dataSource.getClientWorkoutLogs(clientId);
    } catch (e) {
      _workoutLogLogger.e('Ошибка при получении истории тренировок:', error: e);
      throw DataException('Ошибка при получении истории тренировок: $e');
    }
  }
}
