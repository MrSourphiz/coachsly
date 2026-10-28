import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class GetWorkoutPlans implements UseCase<List<WorkoutPlan>, String> {
  final WorkoutPlanRepository repository;

  GetWorkoutPlans(this.repository);

  @override
  Future<List<WorkoutPlan>> execute(String userId) async {
    try {
      return await repository.getWorkoutPlans(userId);

    } catch (e) {
      throw DataException('Ошибка при получении планов тренировок: $e');
    }
  }
}
