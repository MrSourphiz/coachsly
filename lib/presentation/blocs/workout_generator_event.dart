part of 'workout_generator_bloc.dart';

abstract class WorkoutGeneratorEvent extends Equatable {
  const WorkoutGeneratorEvent();
}

class GenerateWorkoutPlanEvent extends WorkoutGeneratorEvent {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> programParams;
  final String accessToken;

  const GenerateWorkoutPlanEvent({
    required this.userData,
    required this.programParams,
    required this.accessToken,
  });

  @override
  List<Object?> get props => [userData, programParams, accessToken];
}