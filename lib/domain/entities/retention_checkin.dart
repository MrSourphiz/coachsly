class RetentionCheckin {
  final String id;
  final String clientId;
  final String trainerId;
  final int wellbeingScore; // 1–5
  final String checkinType; // 'biweekly' | 'block_end' | 'subscription_end'
  final String? note;
  final DateTime createdAt;

  const RetentionCheckin({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.wellbeingScore,
    required this.checkinType,
    this.note,
    required this.createdAt,
  });

  factory RetentionCheckin.fromJson(Map<String, dynamic> json) {
    return RetentionCheckin(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      trainerId: json['trainer_id'] as String,
      wellbeingScore: json['wellbeing_score'] as int,
      checkinType: json['checkin_type'] as String? ?? 'biweekly',
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'trainer_id': trainerId,
    'wellbeing_score': wellbeingScore,
    'checkin_type': checkinType,
    if (note != null) 'note': note,
  };

  String get scoreLabel {
    const labels = {
      1: '😔 Плохо',
      2: '😕 Не очень',
      3: '😐 Нормально',
      4: '🙂 Хорошо',
      5: '😄 Отлично',
    };
    return labels[wellbeingScore] ?? '$wellbeingScore/5';
  }
}
