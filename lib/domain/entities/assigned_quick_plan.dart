import 'package:equatable/equatable.dart';

class AssignedQuickPlan extends Equatable {
  final String id;
  final String trainerId;
  final String clientId;
  final String quickPlanId;
  final DateTime startDate;
  final List<String> trainingDays; // ['monday', 'wednesday', 'friday']
  final int? durationWeeks;        // null = бессрочно
  final String status;             // 'active' | 'archived'
  final DateTime createdAt;

  const AssignedQuickPlan({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.quickPlanId,
    required this.startDate,
    required this.trainingDays,
    this.durationWeeks,
    this.status = 'active',
    required this.createdAt,
  });

  factory AssignedQuickPlan.fromJson(Map<String, dynamic> json) {
    return AssignedQuickPlan(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
      clientId: json['client_id'] as String,
      quickPlanId: json['quick_plan_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      trainingDays: List<String>.from(json['training_days'] as List),
      durationWeeks: json['duration_weeks'] as int?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, trainerId, clientId, quickPlanId, startDate,
    trainingDays, durationWeeks, status, createdAt,
  ];
}

/// Сводка активной быстрой программы клиента — используется на экране
/// создания записи (add_schedule_entry_screen.dart), чтобы предложить
/// тренеру выбрать день программы для брони.
///
/// dayNumbers — уникальные значения quick_plan_exercises.day_of_week
/// (порядковый индекс дня в программе, НЕ обязательно день недели),
/// отсортированные по возрастанию.
/// dayLabels — метка каждого дня (day_label), как её ввёл тренер в тексте
/// программы: день недели, группа мышц или "День N" как fallback.
class ActiveQuickPlanInfo extends Equatable {
  final String quickPlanId;
  final String planName;
  final List<int> dayNumbers;
  final Map<int, String> dayLabels;

  const ActiveQuickPlanInfo({
    required this.quickPlanId,
    required this.planName,
    required this.dayNumbers,
    required this.dayLabels,
  });

  @override
  List<Object?> get props => [quickPlanId, planName, dayNumbers, dayLabels];
}

/// Клиент, которому назначена конкретная быстрая программа —
/// для отображения списка на экране просмотра программы.
class AssignedPlanClient extends Equatable {
  final String clientId;
  final String clientName;
  final DateTime startDate;
  final List<String> trainingDays;

  const AssignedPlanClient({
    required this.clientId,
    required this.clientName,
    required this.startDate,
    required this.trainingDays,
  });

  @override
  List<Object?> get props => [clientId, clientName, startDate, trainingDays];
}
