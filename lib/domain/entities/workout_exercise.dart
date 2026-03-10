import 'package:coachsly/domain/entities/exercise_model.dart';

class WorkoutExercise {
  final String id;
  final Exercise exercise;
  final String note;
  final int restSeconds;
  final int warmupSets;
  final int workSets;
  final int reps;

  WorkoutExercise({
    required this.id,
    required this.exercise,
    required this.note,
    required this.restSeconds,
    required this.warmupSets,
    required this.workSets,
    required this.reps,
  });
}
