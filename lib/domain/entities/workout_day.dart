import 'package:equatable/equatable.dart';
import 'package:coachsly/domain/entities/exercise.dart';

class WorkoutDay {
  final String weekday;
  String? title;
  String? description;
  List<Exercise> exercises;

  WorkoutDay({
    required this.weekday,
    this.title,
    this.description,
    this.exercises = const [],
  });
}