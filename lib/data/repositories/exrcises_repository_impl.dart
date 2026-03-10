import 'package:coachsly/domain/entities/exercise.dart';
import 'package:coachsly/domain/repositories/exercises_repository.dart';
import 'package:coachsly/data/sources/supabase_data_source.dart';

class ExerciseRepositoryImpl implements ExercisesRepository {
  final SupabaseDataSource _dataSource;

  ExerciseRepositoryImpl(this._dataSource);

  final Map<String, List<Exercise>> _cache = {};

  String _key({
    List<String>? categories,
    List<String>? muscles,
    List<String>? equipment,
    List<String>? difficulty,
  }) {
    return [
      categories?.join(',') ?? '',
      muscles?.join(',') ?? '',
      equipment?.join(',') ?? '',
      difficulty?.join(',') ?? '',
    ].join('|');
  }

  @override
  Future<List<Exercise>> getExercises({
    List<String>? categories,
    List<String>? muscles,
    List<String>? equipment,
    List<String>? difficulty,
  }) async {
    final cacheKey = _key(
      categories: categories,
      muscles: muscles,
      equipment: equipment,
      difficulty: difficulty,
    );

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final result = await _dataSource.fetchExercises(
      categories: categories,
      muscles: muscles,
      equipment: equipment,
      difficulty: difficulty,
    );

    _cache[cacheKey] = result;
    return result;
  }
}