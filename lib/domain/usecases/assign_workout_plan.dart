import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/assigned_workout_plan.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class AssignWorkoutPlan implements UseCase<AssignedWorkoutProgram, AssignedWorkoutProgram> {
  final WorkoutPlanRepository repository;

  AssignWorkoutPlan(this.repository);

  @override
  Future<AssignedWorkoutProgram> execute(AssignedWorkoutProgram plan) async {
    try {
      return await repository.assignWorkoutPlan(plan);
    } catch (e) {
      throw DataException('Ошибка при назначении плана тренировки: $e');
    }
  }
}