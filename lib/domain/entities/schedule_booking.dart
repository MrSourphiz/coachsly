import 'package:equatable/equatable.dart';

class ScheduleBooking extends Equatable {
  final String id;
  final DateTime scheduledAt;
  final String timezone;

  final String trainerId;
  final String clientId;

  final String sessionType; // 'single' | 'consultation' | 'program_day'
  final String status; // 'scheduled' | 'confirmed' | 'canceled' | 'completed'

  final String? workoutPlanId;
  final int? workoutDayNumber;

  final String? description;

  const ScheduleBooking({
    required this.id,
    required this.scheduledAt,
    required this.timezone,
    required this.trainerId,
    required this.clientId,
    required this.sessionType,
    required this.status,
    this.workoutPlanId,
    this.workoutDayNumber,
    this.description,
  });

  ScheduleBooking copyWith({
    String? id,
    DateTime? scheduledAt,
    String? timezone,
    String? trainerId,
    String? clientId,
    String? sessionType,
    String? status,
    String? workoutPlanId,
    int? workoutDayNumber,
    String? description,
  }) {
    return ScheduleBooking(
      id: id ?? this.id,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      timezone: timezone ?? this.timezone,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      sessionType: sessionType ?? this.sessionType,
      status: status ?? this.status,
      workoutPlanId: workoutPlanId ?? this.workoutPlanId,
      workoutDayNumber: workoutDayNumber ?? this.workoutDayNumber,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'trainer_id': trainerId,
    'client_id': clientId,
    'session_type': sessionType,
    'status': status,
    'workout_plan_id': workoutPlanId,
    'workout_day_number': workoutDayNumber,
    'description': description ?? '',
  };

  factory ScheduleBooking.fromJson(Map<String, dynamic> json) => ScheduleBooking(
    id: json['id'] as String,
    scheduledAt: DateTime.parse(json['scheduled_at']).toUtc(),
    timezone: json['timezone'] as String,
    trainerId: json['trainer_id'] as String,
    clientId: json['client_id'] as String,
    sessionType: json['session_type'] as String,
    status: json['status'] as String,
    workoutPlanId: json['workout_plan_id'] as String?,
    workoutDayNumber: json['workout_day_number'] as int?,
    description: json['description'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    scheduledAt,
    timezone,
    trainerId,
    clientId,
    sessionType,
    status,
    workoutPlanId,
    workoutDayNumber,
    description,
  ];
}
