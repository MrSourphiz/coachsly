import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class Schedule extends Equatable {
  final String? id;
  final DateTime scheduledAt;
  final String timezone;

  final String trainerId;
  final String clientId;

  final String sessionType; // 'single' | 'consultation' | 'program_day'
  final String status; // computed display status

  // Raw Supabase fields — used for precise visual state resolution
  final String bookingState;       // 'scheduled' | 'canceled' | 'rescheduled' | 'completed'
  final String confirmationState;  // 'pending' | 'confirmed' | 'no_response'
  final DateTime? createdAt;       // when the session was booked
  final bool isPaid;               // true when a linked payment with status='paid' exists

  // FIX: момент когда клиенту отправлено уведомление о записи (booking_created).
  // null  → уведомление ещё НЕ ушло → grace-период (тренер в буфере, клиент не знает).
  // !null → клиент уведомлён → начинается обратный отсчёт 24ч / 8ч.
  // Это надёжнее чем таймер createdAt + 60 мин, потому что реально отражает
  // состояние в очереди уведомлений на бэкенде.
  final DateTime? bookingCreatedNotifiedAt;

  final String? workoutPlanId;
  final int? workoutDayNumber;

  // Привязка к быстрой программе (quick_workout_plans), назначенной клиенту
  // через assigned_quick_plans. День указывается вручную тренером при
  // создании записи (см. add_schedule_entry_screen.dart) — индексация
  // 0=Понедельник...6=Воскресенье, как в quick_plan_exercises.day_of_week.
  final String? quickPlanId;
  final int? quickPlanDayOfWeek;

  final String? description;

  /// Дата новой брони при переносе.
  /// Заполняется только когда booking_state = 'rescheduled'.
  final DateTime? rescheduledToAt;

  /// Порядковый номер тренировки внутри блока (1, 2, 3...).
  /// Заполняется только для session_type == 'block', когда есть
  /// привязка к training_blocks (reserved_block_id). Считается на бэкенде
  /// в get_schedules_with_rescheduled.
  final int? blockSessionNumber;

  /// Общее число тренировок в блоке (training_blocks.total_sessions).
  final int? blockTotalSessions;

  const Schedule({
    this.id,
    required this.scheduledAt,
    required this.timezone,
    required this.trainerId,
    required this.clientId,
    required this.sessionType,
    required this.status,
    this.bookingState = 'scheduled',
    this.confirmationState = 'pending',
    this.createdAt,
    this.isPaid = false,
    this.bookingCreatedNotifiedAt,
    this.workoutPlanId,
    this.workoutDayNumber,
    this.quickPlanId,
    this.quickPlanDayOfWeek,
    this.description,
    this.rescheduledToAt,
    this.blockSessionNumber,
    this.blockTotalSessions,
  });

  // true пока клиент не получил уведомление о записи
  bool get isInGracePeriod => bookingCreatedNotifiedAt == null;

  Schedule copyWith({
    String? id,
    DateTime? scheduledAt,
    String? timezone,
    String? trainerId,
    String? clientId,
    String? sessionType,
    String? status,
    String? bookingState,
    String? confirmationState,
    DateTime? createdAt,
    bool? isPaid,
    DateTime? bookingCreatedNotifiedAt,
    String? workoutPlanId,
    int? workoutDayNumber,
    String? quickPlanId,
    int? quickPlanDayOfWeek,
    String? description,
    DateTime? rescheduledToAt,
    int? blockSessionNumber,
    int? blockTotalSessions,
  }) {
    return Schedule(
      id: id ?? this.id,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      timezone: timezone ?? this.timezone,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      sessionType: sessionType ?? this.sessionType,
      status: status ?? this.status,
      bookingState: bookingState ?? this.bookingState,
      confirmationState: confirmationState ?? this.confirmationState,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      bookingCreatedNotifiedAt:
      bookingCreatedNotifiedAt ?? this.bookingCreatedNotifiedAt,
      workoutPlanId: workoutPlanId ?? this.workoutPlanId,
      workoutDayNumber: workoutDayNumber ?? this.workoutDayNumber,
      quickPlanId: quickPlanId ?? this.quickPlanId,
      quickPlanDayOfWeek: quickPlanDayOfWeek ?? this.quickPlanDayOfWeek,
      description: description ?? this.description,
      rescheduledToAt: rescheduledToAt ?? this.rescheduledToAt,
      blockSessionNumber: blockSessionNumber ?? this.blockSessionNumber,
      blockTotalSessions: blockTotalSessions ?? this.blockTotalSessions,
    );
  }

  Map<String, dynamic> toJson() => {
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'trainer_id': trainerId,
    'client_id': clientId,
    'session_type': sessionType,
    'workout_plan_id': workoutPlanId,
    'workout_day_number': workoutDayNumber,
    'quick_plan_id': quickPlanId,
    'quick_plan_day_of_week': quickPlanDayOfWeek,
    'description': description ?? '',
  };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final bookingState = json['booking_state'] as String? ?? 'scheduled';
    final confirmationState =
        json['confirmation_state'] as String? ?? 'pending';

    String status;
    if (bookingState == 'canceled') {
      status = 'canceled';
    } else if (bookingState == 'rescheduled') {
      status = 'rescheduled';
    } else if (bookingState == 'completed') {
      status = 'completed';
    } else if (confirmationState == 'confirmed') {
      status = 'confirmed';
    } else if (confirmationState == 'no_response') {
      status = 'no_response';
    } else {
      status = 'scheduled';
    }

    DateTime? createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'] as String)?.toUtc();
    }

    // FIX: парсим booking_created_notified_at
    DateTime? bookingCreatedNotifiedAt;
    if (json['booking_created_notified_at'] != null) {
      bookingCreatedNotifiedAt =
          DateTime.tryParse(json['booking_created_notified_at'] as String)
              ?.toUtc();
    }

    // isPaid: populated either when the query joins payments table,
    // when an explicit is_paid boolean is present, or (актуальный кейс)
    // когда пришло сырое поле bookings.payment_state — так возвращает
    // RPC get_schedules_with_rescheduled и Realtime postgres_changes
    // на таблице bookings.
    final paymentsRaw = json['payments'];
    bool isPaid = false;
    if (paymentsRaw is List && paymentsRaw.isNotEmpty) {
      isPaid = paymentsRaw.any((p) => (p as Map)['status'] == 'paid');
    } else if (json['is_paid'] is bool) {
      isPaid = json['is_paid'] as bool;
    } else if (json['payment_state'] is String) {
      isPaid = json['payment_state'] == 'paid';
    }

    // rescheduled_to_at — из SQL функции get_schedules_with_rescheduled
    DateTime? rescheduledToAt;
    if (json['rescheduled_to_at'] != null) {
      rescheduledToAt =
          DateTime.tryParse(json['rescheduled_to_at'] as String)?.toUtc();
    }

    if (bookingState == 'rescheduled') {
      debugPrint('Schedule.fromJson RESCHEDULED: id=${json['id']} rescheduled_to_at=${json['rescheduled_to_at']} parsed=$rescheduledToAt');
    }

    return Schedule(
      id: json['id'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at']).toUtc(),
      timezone: json['timezone'] as String,
      trainerId: json['trainer_id'] as String,
      clientId: json['client_id'] as String,
      sessionType: json['session_type'] as String,
      status: status,
      bookingState: bookingState,
      confirmationState: confirmationState,
      createdAt: createdAt,
      isPaid: isPaid,
      bookingCreatedNotifiedAt: bookingCreatedNotifiedAt,
      workoutPlanId: json['workout_plan_id'] as String?,
      workoutDayNumber: json['workout_day_number'] as int?,
      quickPlanId: json['quick_plan_id'] as String?,
      quickPlanDayOfWeek: json['quick_plan_day_of_week'] as int?,
      description: json['description'] as String?,
      rescheduledToAt: rescheduledToAt,
      blockSessionNumber: json['block_session_number'] as int?,
      blockTotalSessions: json['block_total_sessions'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    scheduledAt,
    timezone,
    trainerId,
    clientId,
    sessionType,
    status,
    bookingState,
    confirmationState,
    createdAt,
    isPaid,
    bookingCreatedNotifiedAt,
    workoutPlanId,
    workoutDayNumber,
    quickPlanId,
    quickPlanDayOfWeek,
    description,
    rescheduledToAt,
    blockSessionNumber,
    blockTotalSessions,
  ];
}
