import 'package:logger/logger.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/data/sources/supabase_data_source.dart';
import 'package:coachsly/domain/entities/training_diary_entry.dart';
import 'package:coachsly/domain/repositories/training_diary_repository.dart';

final logger = Logger();

class TrainingDiaryRepositoryImpl implements TrainingDiaryRepository {
  final SupabaseDataSource _dataSource;

  TrainingDiaryRepositoryImpl(this._dataSource);

  @override
  Future<List<TrainingDiaryEntry>> getEntries(String userId) async {
    final response = await _dataSource.getTrainingDiaryEntries(userId);
    return response.map((json) => TrainingDiaryEntry.fromJson(json)).toList();
  }

  @override
  Future<void> addEntry(TrainingDiaryEntry entry) async {
    try {
      // Вызываем метод addTrainingDiaryEntry из SupabaseDataSource, передавая данные Дневника
      await _dataSource.addTrainingDiaryEntry(entry.toJson());
    } catch (e) {
      // Обрабатываем возможные ошибки
      logger.e('Ошибка при добавлении Дневника тренировок:', error:e );
      throw DataException('Ошибка при добавлении Дневника тренировок: $e');
    }
  }

}