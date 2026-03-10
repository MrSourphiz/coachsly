import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/training_diary_entry.dart';
import 'package:coachsly/domain/usecases/get_training_diary_entries.dart';

abstract class TrainingDiaryEvent {}

class FetchTrainingDiary extends TrainingDiaryEvent {
  final String userId;
  FetchTrainingDiary(this.userId);
}

abstract class TrainingDiaryState {}

class TrainingDiaryInitial extends TrainingDiaryState {}

class TrainingDiaryLoading extends TrainingDiaryState {}

class TrainingDiarySuccess extends TrainingDiaryState {
  final List<TrainingDiaryEntry> entries;
  TrainingDiarySuccess(this.entries);
}

class TrainingDiaryError extends TrainingDiaryState {
  final String message;
  TrainingDiaryError(this.message);
}

class TrainingDiaryBloc extends Bloc<TrainingDiaryEvent, TrainingDiaryState> {
  final GetTrainingDiaryEntries getTrainingDiaryEntries;

  TrainingDiaryBloc({
    required this.getTrainingDiaryEntries,
  }) : super(TrainingDiaryInitial()) {
    on<FetchTrainingDiary>(_onFetchTrainingDiary);
  }

  @override
  Future<void> _onFetchTrainingDiary(FetchTrainingDiary event, Emitter<TrainingDiaryState> emit) async {
    emit(TrainingDiaryLoading());
    try {
      final entries = await getTrainingDiaryEntries.execute(event.userId);
      emit(TrainingDiarySuccess(entries));
    } catch (e) {
      emit(TrainingDiaryError('Ошибка загрузки дневника тренировок: $e'));
    }
  }
}