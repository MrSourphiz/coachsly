import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/domain/entities/exercise.dart';
import 'package:coachsly/domain/repositories/exercises_repository.dart';

// События
abstract class ExercisePickerEvent {}

class UpdateFiltersEvent extends ExercisePickerEvent {
  final List<String> categories;
  final List<String> muscles;
  final List<String> equipment;
  final List<String> difficulty;

  UpdateFiltersEvent({
    required this.categories,
    required this.muscles,
    required this.equipment,
    required this.difficulty,
  });
}

class ResetFiltersEvent extends ExercisePickerEvent {}

// Состояния
abstract class ExercisePickerState {
  final bool loading;
  final List<Exercise> exercises;

  const ExercisePickerState({
    required this.loading,
    required this.exercises,
  });
}

class ExercisePickerInitial extends ExercisePickerState {
  const ExercisePickerInitial()
      : super(loading: false, exercises: const []);
}

class ExercisePickerLoading extends ExercisePickerState {
  const ExercisePickerLoading(List<Exercise> exercises)
      : super(loading: true, exercises: exercises);
}

class ExercisePickerLoaded extends ExercisePickerState {
  const ExercisePickerLoaded(List<Exercise> exercises)
      : super(loading: false, exercises: exercises);
}

class ExercisePickerError extends ExercisePickerState {
  final String error;

  const ExercisePickerError(List<Exercise> exercises, this.error)
      : super(loading: false, exercises: exercises);
}

// BLoC (максимально упрощенная версия)
class ExercisePickerBloc extends Bloc<ExercisePickerEvent, ExercisePickerState> {
  final ExercisesRepository repository;

  ExercisePickerBloc(this.repository) : super(const ExercisePickerInitial()) {
    on<UpdateFiltersEvent>(_onUpdateFilters);
    on<ResetFiltersEvent>(_onResetFilters);
  }

  Future<void> _onUpdateFilters(
      UpdateFiltersEvent event,
      Emitter<ExercisePickerState> emit,
      ) async {
    // Немедленно показываем состояние загрузки
    emit(ExercisePickerLoading(state.exercises));

    try {
      final result = await repository.getExercises(
        categories: event.categories,
        muscles: event.muscles,
        equipment: event.equipment,
        difficulty: event.difficulty,
      );

      emit(ExercisePickerLoaded(result));
    } catch (e) {
      emit(ExercisePickerError(state.exercises, e.toString()));
    }
  }

  void _onResetFilters(ResetFiltersEvent event, Emitter<ExercisePickerState> emit) {
    emit(const ExercisePickerInitial());
  }
}