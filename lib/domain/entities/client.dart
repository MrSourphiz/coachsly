import 'package:equatable/equatable.dart';

class Client extends Equatable {
  final String id;
  final int telegramUserId;
  final String trainerId;
  final String first_name;
  final String last_name;
  final String status;
  final String? notes;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasActiveProgram;
  final String? assignedProgramId;
  final List<String>? trainingDays;
  final int? durationWeeks;

  const Client({
    required this.id,
    required this.telegramUserId,
    required this.trainerId,
    required this.first_name,
    required this.last_name,
    required this.status,
    this.notes,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.hasActiveProgram,
    required this.assignedProgramId,
    required this.trainingDays,
    required this.durationWeeks,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    try {
      final status = json['status'] as String? ?? 'pending';
      if (json['telegram_user_id'] == null) {
        throw FormatException('telegram_user_id is null in JSON: $json');
      }
      if (json['trainer_id'] == null) {
        throw FormatException('trainer_id is null in JSON: $json');
      }
      if (json['created_at'] == null || json['updated_at'] == null) {
        throw FormatException('created_at or updated_at is null in JSON: $json');
      }
      if (json['first_name'] == null) {
        throw FormatException('first_name is null in JSON: $json');
      }
      if (json['last_name'] == null) {
        throw FormatException('last_name is null in JSON: $json');
      }
      return Client(
        id: json['id'] as String,
        telegramUserId: json['telegram_user_id'] ?? 0,
        trainerId: json['trainer_id'] as String,
        status: status,
        notes: json['notes'] as String?,
        first_name: json['first_name'] as String,
        last_name: json['last_name'] as String,
        phoneNumber: json['phone_number'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        hasActiveProgram: json['hasActiveProgram'] ?? false,
        assignedProgramId: json['assignedProgramId'] as String?,
        trainingDays: (json['trainingDays'] as List<dynamic>?)
            ?.cast<String>()
            ?? [],
        durationWeeks: json['hasActiveProgram'] ?? 0,
      );
    } catch (e) {
      print('Client.fromJson error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trainer_id': trainerId,
      'first_name': first_name,
      'last_name': last_name,
      'status': status,
      'notes': notes,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'hasActiveProgram': hasActiveProgram,
      'assignedProgramId': assignedProgramId,
      'trainingDays': trainingDays,
      'durationWeeks': durationWeeks,
    };
  }

  @override
  List<Object?> get props => [
    id,
    trainerId,
    first_name,
    last_name,
    status,
    notes,
    phoneNumber,
    createdAt,
    updatedAt,
    hasActiveProgram,
    assignedProgramId,
    trainingDays,
    durationWeeks,
  ];

  @override
  String toString() =>
      'Client('
          'id: $id, '
          'trainerId: $trainerId, '
          'first_name: $first_name, '
          'last_name: $last_name, '
          'status: $status, '
          'phoneNumber: $phoneNumber, '
          'notes: $notes,'
          'hasActiveProgram: $hasActiveProgram,'
          'assignedProgramId: $assignedProgramId,'
          'trainingDays: $trainingDays,'
          'durationWeeks: $durationWeeks)';
}