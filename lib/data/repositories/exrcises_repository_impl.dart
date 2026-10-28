import 'package:formeo/domain/entities/exercise.dart';
import 'package:formeo/domain/repositories/exercises_repository.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';

class ExerciseRepositoryImpl implements ExercisesRepository {
  final SupabaseDataSource _dataSource;

  ExerciseRepositoryImpl(this._dataSource);

  // Кэш живёт 24 часа — после этого данные будут перезапрошены.
  static const _cacheTtl = Duration(hours: 24);

  final Map<String, List<Exercise>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

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

  bool _isCacheValid(String key) {
    final ts = _cacheTimestamps[key];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cacheTtl;
  }

  /// Принудительно сбрасывает весь кэш (например, при логауте).
  void invalidate() {
    _cache.clear();
    _cacheTimestamps.clear();
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

    if (_cache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final result = await _dataSource.fetchExercises(
      categories: categories,
      muscles: muscles,
      equipment: equipment,
      difficulty: difficulty,
    );

    _cache[cacheKey] = result;
    _cacheTimestamps[cacheKey] = DateTime.now();
    return result;
  }
}
