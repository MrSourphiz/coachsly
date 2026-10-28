import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/assigned_workout_plan.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

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
