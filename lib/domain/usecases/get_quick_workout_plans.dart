import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class GetQuickWorkoutPlans implements UseCase<List<QuickWorkoutPlan>, String> {
  final WorkoutPlanRepository repository;

  GetQuickWorkoutPlans(this.repository);

  @override
  Future<List<QuickWorkoutPlan>> execute(String userId) async {
    try {
      return await repository.getQuickWorkoutPlans(userId);
    } catch (e) {
      throw DataException('Ошибка при получении планов тренировок: $e');
    }
  }
}
