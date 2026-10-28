class Payment {
  final String id;
  final String? bookingId;
  final double? amount;
  final String? status;
  final String? paymentMethod;
  final String? receiptPhotoUrl;
  final String? receiptFileId;
  final String? purchaseType;
  final String? clientId;
  final String? trainerId;
  final DateTime createdAt;

  const Payment({
    required this.id,
    this.bookingId,
    this.amount,
    this.status,
    this.paymentMethod,
    this.receiptPhotoUrl,
    this.receiptFileId,
    this.purchaseType,
    this.clientId,
    this.trainerId,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    status: json['status'] as String?,
    paymentMethod: json['payment_method'] as String?,
    receiptPhotoUrl: json['receipt_photo_url'] as String?,
    receiptFileId: json['receipt_file_id'] as String?,
    purchaseType: json['purchase_type'] as String?,
    clientId: json['client_id'] as String?,
    trainerId: json['trainer_id'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
