class RetentionSignal {
  final String id;
  final String clientId;
  final String trainerId;
  final String signalLevel; // 'red' | 'yellow' | 'green'
  final String reason;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  // Дополнительные данные клиента (JOIN при запросе)
  final String? clientName;

  const RetentionSignal({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.signalLevel,
    required this.reason,
    this.resolvedAt,
    required this.createdAt,
    this.clientName,
  });

  bool get isResolved => resolvedAt != null;

  factory RetentionSignal.fromJson(Map<String, dynamic> json) {
    return RetentionSignal(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      trainerId: json['trainer_id'] as String,
      signalLevel: json['signal_level'] as String,
      reason: json['reason'] as String,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      clientName: json['client_name'] as String?,
    );
  }

  String get reasonLabel {
    const labels = {
      'missed_2_sessions': '2 пропуска подряд',
      'low_wellbeing_twice': 'Оценка 1–2 дважды подряд',
      'attendance_below_50': 'Посещаемость < 50% за 2 недели',
    };
    return labels[reason] ?? reason;
  }

  /// Короткий практический совет тренеру — что сделать прямо сейчас
  /// по этому конкретному сигналу. Показывается в карточке сигнала
  /// на экране клиента (см. _SignalCard в retention_client_section.dart).
  String get advice {
    switch (reason) {
      case 'missed_2_sessions':
        return 'Клиент дважды подряд пропустил тренировку. Напишите лично, узнайте причину и сразу предложите ближайшую удобную дату — не дожидаясь следующего чек-ина.';
      case 'low_wellbeing_twice':
        return 'Клиент дважды подряд отметил низкое самочувствие. Обсудите нагрузку и внешние обстоятельства — возможно, стоит облегчить программу на ближайшую неделю.';
      case 'attendance_below_50':
        return 'Посещаемость упала ниже 50% за 2 недели. Позвоните и предложите пересмотреть расписание или формат занятий, пока клиент не принял решение уйти.';
      default:
        return 'Свяжитесь с клиентом лично, чтобы понять, что происходит, и предложить поддержку.';
    }
  }

  String get levelEmoji {
    switch (signalLevel) {
      case 'red':
        return '🔴';
      case 'yellow':
        return '🟡';
      default:
        return '🟢';
    }
  }
}