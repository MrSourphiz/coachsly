import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/entities/assigned_workout_plan.dart';
import 'package:formeo/domain/entities/assigned_quick_plan.dart';
//абстрактный интерфейс репозитория
abstract class WorkoutPlanRepository {
  Future<List<WorkoutPlan>> getWorkoutPlans(String userId);
  Future<List<QuickWorkoutPlan>>getQuickWorkoutPlans(String userId);
  Future<List<AssignedWorkoutProgram>>getClientsWorkoutPlans(String userId);
  Future<AssignedWorkoutProgram> assignWorkoutPlan(AssignedWorkoutProgram plan);
  Future<void> updateAssignedWorkoutPlan(AssignedWorkoutProgram plan);
  Future<void> deleteAssignedWorkoutPlan(String planId);

  Future<void> createWorkoutPlan(String userId, WorkoutPlan plan);
  Future<void> changeWorkoutPlan(WorkoutPlan plan);
  Future<AssignedQuickPlan> assignQuickWorkoutPlan(AssignedQuickPlan assignment);
  Future<String?> getActiveQuickPlanName(String clientId);

  /// Полная сводка активной быстрой программы клиента (id, название,
  /// доступные дни программы) — используется при создании записи
  /// в расписании, чтобы предложить тренеру выбрать день программы.
  Future<ActiveQuickPlanInfo?> getActiveQuickPlanInfo(String clientId);

  /// Клиенты с активным назначением этой быстрой программы —
  /// для отображения на экране просмотра программы.
  Future<List<AssignedPlanClient>> getClientsForQuickPlan(String quickPlanId);
}
