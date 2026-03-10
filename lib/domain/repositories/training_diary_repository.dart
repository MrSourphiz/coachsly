import 'package:coachsly/domain/entities/training_diary_entry.dart';

abstract class TrainingDiaryRepository {
  Future<List<TrainingDiaryEntry>> getEntries(String userId);
  Future<void> addEntry(TrainingDiaryEntry entry);
}