class TrainerPaymentDetail {
  final String id;
  final String trainerId;
  final String bankName;
  final String requisites;
  final String? phoneNumber;
  final DateTime createdAt;

  TrainerPaymentDetail({
    required this.id,
    required this.trainerId,
    required this.bankName,
    required this.requisites,
    this.phoneNumber,
    required this.createdAt,
  });

  factory TrainerPaymentDetail.fromMap(Map<String, dynamic> map) {
    return TrainerPaymentDetail(
      id: map['id'] ?? '',
      trainerId: map['trainer_id'] ?? '',
      bankName: map['bank_name'] ?? '',
      requisites: map['requisites'] ?? '',
      phoneNumber: map['phone_number'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}