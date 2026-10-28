import 'package:equatable/equatable.dart';

/// Факт тренировки — одна запись на одну сессию (обычно = одна бронь).
class WorkoutLog extends Equatable {
  final String id;
  final String trainerId;
  final String clientId;
  final String? bookingId;
  final String quickPlanId;
  final int dayOfWeek;
  final DateTime performedAt;
  final String status; // 'in_progress' | 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutLog({
    required this.id,
    required this.trainerId,
    required this.clientId,
    this.bookingId,
    required this.quickPlanId,
    required this.dayOfWeek,
    required this.performedAt,
    this.status = 'in_progress',
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
      clientId: json['client_id'] as String,
      bookingId: json['booking_id'] as String?,
      quickPlanId: json['quick_plan_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      performedAt: DateTime.parse(json['performed_at'] as String),
      status: json['status'] as String? ?? 'in_progress',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, trainerId, clientId, bookingId, quickPlanId, dayOfWeek,
    performedAt, status, createdAt, updatedAt,
  ];
}

/// Фактически выполненный подход конкретного упражнения в рамках [WorkoutLog].
class WorkoutLogSet extends Equatable {
  final String? id;
  final String workoutLogId;
  final String quickPlanExerciseId;
  final int setNumber;
  final int? repsActual;
  final double? weightActual;
  final bool completed;

  const WorkoutLogSet({
    this.id,
    required this.workoutLogId,
    required this.quickPlanExerciseId,
    required this.setNumber,
    this.repsActual,
    this.weightActual,
    this.completed = false,
  });

  factory WorkoutLogSet.fromJson(Map<String, dynamic> json) {
    return WorkoutLogSet(
      id: json['id'] as String?,
      workoutLogId: json['workout_log_id'] as String,
      quickPlanExerciseId: json['quick_plan_exercise_id'] as String,
      setNumber: json['set_number'] as int,
      repsActual: json['reps_actual'] as int?,
      weightActual: (json['weight_actual'] as num?)?.toDouble(),
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'workout_log_id': workoutLogId,
    'quick_plan_exercise_id': quickPlanExerciseId,
    'set_number': setNumber,
    'reps_actual': repsActual,
    'weight_actual': weightActual,
    'completed': completed,
  };

  WorkoutLogSet copyWith({
    String? id,
    int? repsActual,
    double? weightActual,
    bool? completed,
  }) {
    return WorkoutLogSet(
      id: id ?? this.id,
      workoutLogId: workoutLogId,
      quickPlanExerciseId: quickPlanExerciseId,
      setNumber: setNumber,
      repsActual: repsActual ?? this.repsActual,
      weightActual: weightActual ?? this.weightActual,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [
    id, workoutLogId, quickPlanExerciseId, setNumber,
    repsActual, weightActual, completed,
  ];
}
