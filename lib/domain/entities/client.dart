import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:formeo/core/constants/messenger.dart';

class Client extends Equatable {
  final String id;

  /// ID в мессенджере: > 0 — Telegram, < 0 — MAX (user_id со знаком минус).
  final int telegramUserId;
  final String trainerId;
  final String firstName;
  final String? lastName;
  final String? username;
  final String defaultSessionType; // 'single' | 'block' | 'subscription'
  final String status;
  final String? notes;
  final bool fatsecretEnabled;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.telegramUserId,
    required this.trainerId,
    required this.firstName,
    this.lastName,
    this.username,
    required this.defaultSessionType,
    required this.status,
    this.notes,
    this.fatsecretEnabled = true,
    this.isDemo = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    try {
      return Client(
        id: json['id'] as String,
        telegramUserId: (json['telegram_user_id'] as num).toInt(),
        trainerId: json['trainer_id'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String?,
        username: json['username'] as String?,
        defaultSessionType: json['default_session_type'] as String? ?? 'single',
        status: json['status'] as String? ?? 'active',
        notes: json['notes'] as String?,
        fatsecretEnabled: json['fatsecret_enabled'] as bool? ?? true,
        isDemo: json['is_demo'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
    } catch (e) {
      debugPrint('Client.fromJson error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'telegram_user_id': telegramUserId,
    'trainer_id': trainerId,
    'first_name': firstName,
    'last_name': lastName,
    'username': username,
    'default_session_type': defaultSessionType,
    'status': status,
    'notes': notes,
    'fatsecret_enabled': fatsecretEnabled,
    'is_demo': isDemo,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Client copyWith({
    String? id,
    int? telegramUserId,
    String? trainerId,
    String? firstName,
    String? lastName,
    String? username,
    String? defaultSessionType,
    String? status,
    String? notes,
    bool? fatsecretEnabled,
    bool? isDemo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      telegramUserId: telegramUserId ?? this.telegramUserId,
      trainerId: trainerId ?? this.trainerId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      defaultSessionType: defaultSessionType ?? this.defaultSessionType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      fatsecretEnabled: fatsecretEnabled ?? this.fatsecretEnabled,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullName => [firstName, lastName]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isDeleted => status == 'deleted';

  /// Мессенджер клиента — определяется знаком telegram_user_id.
  Messenger get messenger => messengerFromTelegramUserId(telegramUserId);
  bool get isMax => messenger == Messenger.max;

  /// user_id в мессенджере (без служебного знака).
  int get messengerUserId => telegramUserId.abs();

  @override
  List<Object?> get props => [
    id,
    telegramUserId,
    trainerId,
    firstName,
    lastName,
    username,
    defaultSessionType,
    status,
    notes,
    fatsecretEnabled,
    isDemo,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() =>
      'Client(id: $id, name: $fullName, messenger: ${messenger.label}, status: $status, defaultSessionType: $defaultSessionType, notes: $notes, fatsecretEnabled: $fatsecretEnabled, isDemo: $isDemo)';
}
