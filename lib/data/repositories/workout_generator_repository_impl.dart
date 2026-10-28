import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/data/sources/workout_generator_remote_data_source.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/repositories/workout_generator_repository.dart';

class WorkoutGeneratorRepositoryImpl implements WorkoutGeneratorRepository {
  final WorkoutGeneratorRemoteDataSource remoteDataSource;

  WorkoutGeneratorRepositoryImpl({required this.remoteDataSource});

  @override
  Future<WorkoutPlan> generateWorkoutPlan({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> programParams,
    required String accessToken,
  }) async {
    try {
      return await remoteDataSource.generateWorkoutPlan(
        userData: userData,
        programParams: programParams,
        accessToken: accessToken,
      );
    } catch (e) {
      // Преобразование исключений в ServerException
      throw ServerException(e.toString());
    }
  }
}
