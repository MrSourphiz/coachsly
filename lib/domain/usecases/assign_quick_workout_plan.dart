import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/assigned_quick_plan.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class AssignQuickWorkoutPlan implements UseCase<AssignedQuickPlan, AssignedQuickPlan> {
  final WorkoutPlanRepository repository;

  AssignQuickWorkoutPlan(this.repository);

  @override
  Future<AssignedQuickPlan> execute(AssignedQuickPlan assignment) async {
    try {
      return await repository.assignQuickWorkoutPlan(assignment);
    } catch (e) {
      throw DataException('Ошибка при назначении программы: $e');
    }
  }
}
