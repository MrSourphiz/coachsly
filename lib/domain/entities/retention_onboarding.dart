class RetentionOnboarding {
  final String id;
  final String clientId;
  final String trainerId;

  // Блок 1 — Цель
  final String goalType;
  final String? goalDescription;

  // Блок 2 — Опыт (ключ Бедфорда)
  final String experienceType; // 'beginner' | 'experienced' | 'yo_yo'
  final String? quitReason;

  // Блок 3 — Уровень поддержки
  final String gymConfidence;  // 'confident' | 'somewhat' | 'needs_support'
  final String coachingStyle;  // 'structured' | 'collaborative' | 'free'

  // Блок 4 — Базовая оценка
  final int baseWellbeing; // 1–5

  final DateTime completedAt;

  const RetentionOnboarding({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.goalType,
    this.goalDescription,
    required this.experienceType,
    this.quitReason,
    required this.gymConfidence,
    required this.coachingStyle,
    required this.baseWellbeing,
    required this.completedAt,
  });

  factory RetentionOnboarding.fromJson(Map<String, dynamic> json) {
    return RetentionOnboarding(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      trainerId: json['trainer_id'] as String,
      goalType: json['goal_type'] as String,
      goalDescription: json['goal_description'] as String?,
      experienceType: json['experience_type'] as String,
      quitReason: json['quit_reason'] as String?,
      gymConfidence: json['gym_confidence'] as String,
      coachingStyle: json['coaching_style'] as String,
      baseWellbeing: json['base_wellbeing'] as int,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'trainer_id': trainerId,
    'goal_type': goalType,
    'goal_description': goalDescription,
    'experience_type': experienceType,
    'quit_reason': quitReason,
    'gym_confidence': gymConfidence,
    'coaching_style': coachingStyle,
    'base_wellbeing': baseWellbeing,
  };

  /// Тип клиента по Бедфорду для отображения тренеру
  String get clientTypeLabel {
    switch (experienceType) {
      case 'beginner':
        return 'Новичок';
      case 'experienced':
        return 'Опытный';
      case 'yo_yo':
        return 'Йо-йо';
      default:
        return experienceType;
    }
  }

  /// Уровень риска (высокий для yo_yo и beginner)
  String get riskLevel {
    if (experienceType == 'yo_yo') return 'high';
    if (experienceType == 'beginner') return 'medium';
    return 'low';
  }

  String get goalTypeLabel {
    const labels = {
      'lose_weight': 'Похудеть / изменить фигуру',
      'get_stronger': 'Стать сильнее и выносливее',
      'improve_health': 'Улучшить здоровье / самочувствие',
      'fix_problem': 'Убрать конкретную проблему',
      'build_habit': 'Войти в привычку двигаться',
      'other': 'Другое',
    };
    return labels[goalType] ?? goalType;
  }
}
