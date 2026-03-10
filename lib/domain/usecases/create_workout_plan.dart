import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class CreateWorkoutPlanParams {
  final String userId;
  final WorkoutPlan workoutPlan;

  CreateWorkoutPlanParams(this.userId, this.workoutPlan);
}

class CreateWorkoutPlan implements UseCase<void, CreateWorkoutPlanParams> {
  final WorkoutPlanRepository repository;

  CreateWorkoutPlan(this.repository);

  @override
  Future<void> execute(CreateWorkoutPlanParams params) async {
    try {
      await repository.createWorkoutPlan(params.userId, params.workoutPlan);
    } catch (e) {
      throw DataException('Ошибка при добавлении плана тренировок: $e');
    }
  }
}