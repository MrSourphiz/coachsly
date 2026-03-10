import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

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