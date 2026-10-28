import 'package:equatable/equatable.dart';

class TrainingDiaryEntry extends Equatable {
  final String id;
  final DateTime date;
  final String workoutType;
  final int durationMinutes;
  final List<String> exercises;
  final String notes;

  TrainingDiaryEntry({
    required this.id,
    required this.date,
    required this.workoutType,
    required this.durationMinutes,
    required this.exercises,
    required this.notes,
  });

  factory TrainingDiaryEntry.fromJson(Map<String, dynamic> json) {
    return TrainingDiaryEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      workoutType: json['workoutType'],
      durationMinutes: json['durationMinutes'],
      exercises: List<String>.from(json['exercises']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'workoutType': workoutType,
      'durationMinutes': durationMinutes,
      'exercises': exercises,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [id, date, workoutType, durationMinutes, exercises, notes];
}
