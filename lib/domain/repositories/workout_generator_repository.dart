import 'package:coachsly/domain/entities/workout_plan_model.dart';

abstract class WorkoutGeneratorRepository {
  Future<WorkoutPlan> generateWorkoutPlan({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> programParams,
    required String accessToken,
  });
}