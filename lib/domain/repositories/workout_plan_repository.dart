import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/domain/entities/assigned_workout_plan.dart';
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
}