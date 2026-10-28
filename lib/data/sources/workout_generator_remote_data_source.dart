import 'package:dio/dio.dart';
import 'package:formeo/core/constants/supabase_constants.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';

abstract class WorkoutGeneratorRemoteDataSource {
  Future<WorkoutPlan> generateWorkoutPlan({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> programParams,
    required String accessToken,
  });
}

class WorkoutGeneratorRemoteDataSourceImpl implements WorkoutGeneratorRemoteDataSource {
  final Dio dio;

  WorkoutGeneratorRemoteDataSourceImpl({required this.dio});

  @override
  Future<WorkoutPlan> generateWorkoutPlan({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> programParams,
    required String accessToken,
  }) async {
    try {
      final response = await dio.post(
        SupabaseConstants.generateWorkoutPlanEndpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          //'Content-Type': 'application/json',
        }),
        data: {
          'user_data': userData,
          'program_params': programParams,
        },
      );

      if (response.statusCode == 200) {
        return WorkoutPlan.fromJson(response.data);
      } else {
        throw ServerException('API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw RateLimitException();
      } else {
        throw ServerException('Network error: ${e.message}');
      }
    }
  }
}
