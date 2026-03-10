import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/assigned_workout_plan.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class UpdateAssignedWorkoutPlan implements UseCase<void, AssignedWorkoutProgram> {
  final WorkoutPlanRepository repository;

  UpdateAssignedWorkoutPlan(this.repository);

  @override
  Future<void> execute(AssignedWorkoutProgram plan) async {
    try {
      await repository.updateAssignedWorkoutPlan(plan);
    } catch (e) {
      throw DataException('Ошибка при обновлении назначенного плана тренировки: $e');
    }
  }
}