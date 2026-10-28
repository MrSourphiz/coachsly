import 'package:formeo/domain/entities/exercise.dart';
//абстрактный интерфейс репозитория
abstract class ExercisesRepository {
  Future<List<Exercise>> getExercises({
    List<String>? categories,
    List<String>? muscles,
    List<String>? equipment,
    List<String>? difficulty,
  });
}
