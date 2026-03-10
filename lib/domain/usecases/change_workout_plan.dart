import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class ChangeWorkoutPlan implements UseCase<void, WorkoutPlan> {
  final WorkoutPlanRepository repository;

  ChangeWorkoutPlan(this.repository);

  @override
  Future<void> execute(WorkoutPlan workoutPlan) async {
    try {
      await repository.changeWorkoutPlan(workoutPlan);
    } catch (e) {
      throw DataException('Ошибка при обновлении плана тренировок: $e');
    }
  }
}