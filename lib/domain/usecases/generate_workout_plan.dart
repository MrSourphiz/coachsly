import 'package:formeo/domain/usecases/use_case.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/repositories/workout_generator_repository.dart';


class GenerateWorkoutPlan implements UseCase<WorkoutPlan, GenerateWorkoutPlanParams> {
  final WorkoutGeneratorRepository repository;

  GenerateWorkoutPlan(this.repository);

  @override
  Future<WorkoutPlan> execute(GenerateWorkoutPlanParams params) async {
    return await repository.generateWorkoutPlan(
      userData: params.userData,
      programParams: params.programParams,
      accessToken: params.accessToken,
    );
  }
}

class GenerateWorkoutPlanParams {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> programParams;
  final String accessToken;

  const GenerateWorkoutPlanParams({
    required this.userData,
    required this.programParams,
    required this.accessToken,
  });

}
