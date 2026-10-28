import 'package:equatable/equatable.dart';

enum WorkoutType { cardio, strength, functional, stretching, custom }

class WorkoutPlan extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String schedule;
  final List<String> exercises;
  final WorkoutType type;

  WorkoutPlan({
    required this.id,
    required this.userId,
    required this.name,
    required this.schedule,
    required this.exercises,
    required this.type,
  });

  static WorkoutType workoutTypeFromString(String type) {
    switch (type) {
      case 'cardio':
        return WorkoutType.cardio;
      case 'strength':
        return WorkoutType.strength;
      case 'functional':
        return WorkoutType.functional;
      case 'stretching':
        return WorkoutType.stretching;
      case 'custom':
        return WorkoutType.custom;
      default:
        throw ArgumentError('Неизвестный тип тренировки: $type');
    }
  }

  static String workoutTypeToString(WorkoutType type) {
    return type.toString().split('.').last; // → 'cardio' и т.д.
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'schedule': schedule,
    'exercises': exercises,
    'type': workoutTypeToString(type),
  };

  static WorkoutPlan fromJson(Map<String, dynamic> json) => WorkoutPlan(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    schedule: json['schedule'] as String,
    exercises: (json['exercises'] as List<dynamic>).cast<String>(),
    type: workoutTypeFromString(json['type'] as String),
  );

  @override
  List<Object?> get props => [id, userId, name, schedule, exercises, type];
}
