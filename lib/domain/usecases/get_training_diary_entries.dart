import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/training_diary_entry.dart';
import 'package:coachsly/domain/repositories/training_diary_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class GetTrainingDiaryEntries implements UseCase<List<TrainingDiaryEntry>, String> {
  final TrainingDiaryRepository repository;

  GetTrainingDiaryEntries(this.repository);

  @override
  Future<List<TrainingDiaryEntry>> execute(String userId) async {
    try {
      return await repository.getEntries(userId);
    } catch (e) {
      throw DataException('Ошибка при получении дневника тренировок: $e');
    }
  }
}