part of 'workout_generator_bloc.dart';

abstract class WorkoutGeneratorState extends Equatable {
  const WorkoutGeneratorState();
}

class WorkoutGeneratorInitial extends WorkoutGeneratorState {
  @override
  List<Object?> get props => [];
}

class WorkoutGeneratorLoading extends WorkoutGeneratorState {
  @override
  List<Object?> get props => [];
}

class WorkoutGeneratorSuccess extends WorkoutGeneratorState {
  final WorkoutPlan plan;

  const WorkoutGeneratorSuccess(this.plan);

  @override
  List<Object?> get props => [plan];
}

class WorkoutGeneratorFailure extends WorkoutGeneratorState {
  final String error;

  const WorkoutGeneratorFailure(this.error);

  @override
  List<Object?> get props => [error];
}