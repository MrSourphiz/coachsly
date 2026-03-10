import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class DeleteAssignedWorkoutPlan implements UseCase<void, String> {
  final WorkoutPlanRepository repository;

  DeleteAssignedWorkoutPlan(this.repository);

  @override
  Future<void> execute(String planId) async {
    try {
      await repository.deleteAssignedWorkoutPlan(planId);
    } catch (e) {
      throw DataException('Ошибка при удалении назначенного плана тренировки: $e');
    }
  }
}