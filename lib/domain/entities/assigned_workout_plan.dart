class AssignedWorkoutProgram {
  final String id;
  final String trainerId;
  final String clientId;
  final String workoutProgramId;
  final DateTime startDate;
  final List<String> trainingDays;
  final int durationWeeks;
  final DateTime createdAt;
  final String type;

  AssignedWorkoutProgram({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.workoutProgramId,
    required this.startDate,
    required this.trainingDays,
    required this.durationWeeks,
    required this.createdAt,
    required this.type,
  });

  factory AssignedWorkoutProgram.fromJson(Map<String, dynamic> json) {
    return AssignedWorkoutProgram(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
      clientId: json['client_id'] as String,
      workoutProgramId: json['workout_program_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      trainingDays: List<String>.from(json['training_days'] as List),
      durationWeeks: json['duration_weeks'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trainer_id': trainerId,
      'client_id': clientId,
      'workout_program_id': workoutProgramId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'training_days': trainingDays,
      'duration_weeks': durationWeeks,
      'type': type,
    };
  }
}
