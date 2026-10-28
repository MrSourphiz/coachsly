import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/assigned_workout_plan.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class GetClientsWorkoutPlans implements UseCase<List<AssignedWorkoutProgram>, String> {
  final WorkoutPlanRepository repository;

  GetClientsWorkoutPlans(this.repository);

  @override
  Future<List<AssignedWorkoutProgram>> execute(String userId) async {
    try {
      return await repository.getClientsWorkoutPlans(userId);
    } catch (e) {
      throw DataException('Ошибка при получении клиентских планов тренировок: $e');
    }
  }
}
