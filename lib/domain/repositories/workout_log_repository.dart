import 'package:formeo/domain/entities/workout_log.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';

abstract class WorkoutLogRepository {
  /// Возвращает существующий журнал тренировки по booking_id (если уже
  /// открывали эту тренировку раньше) или создаёт новый.
  Future<WorkoutLog> getOrCreateWorkoutLog({
    required String trainerId,
    required String clientId,
    String? bookingId,
    required String quickPlanId,
    required int dayOfWeek,
    required DateTime performedAt,
  });

  /// Упражнения плана для конкретного дня программы, отсортированные
  /// по порядку выполнения.
  Future<List<QuickPlanExercise>> getPlanExercisesForDay(String quickPlanId, int dayOfWeek);

  Future<List<WorkoutLogSet>> getWorkoutLogSets(String workoutLogId);

  /// Сохраняет один подход (insert или update — по уникальности
  /// workout_log_id + quick_plan_exercise_id + set_number).
  Future<WorkoutLogSet> upsertWorkoutLogSet(WorkoutLogSet set);

  /// Помечает тренировку как завершённую.
  Future<void> completeWorkoutLog(String workoutLogId);

  /// История тренировок клиента (сырые данные с вложенными подходами
  /// и именами упражнений) — для отображения в карточке клиента.
  Future<List<Map<String, dynamic>>> getClientWorkoutLogs(String clientId);
}
