import 'package:coachsly/domain/entities/trainer_payment_detail.dart';


import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Сохранение реквизитов тренера
  Future<void> saveTrainerPaymentDetails({
    required String bankName,
    required String requisites,
    String? phoneNumber,
  }) async {
    final trainerId = _supabase.auth.currentUser?.id;
    if (trainerId == null) throw Exception('Пользователь не авторизован');

    await _supabase.from('trainer_payment_details').upsert({
      'trainer_id': trainerId,
      'bank_name': bankName,
      'requisites': requisites,
      'phone_number': phoneNumber,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Получение реквизитов тренера
  Future<TrainerPaymentDetail?> getTrainerPaymentDetails() async {
    final trainerId = _supabase.auth.currentUser?.id;
    if (trainerId == null) return null;

    final response = await _supabase
        .from('trainer_payment_details')
        .select()
        .eq('trainer_id', trainerId)
        .single()
        .execute();

    if (response.data != null) {
      return TrainerPaymentDetail.fromMap(response.data);
    }
    return null;
  }

  // Получение уведомлений тренера (с realtime подпиской)
  Stream<List<TrainerNotification>> getNotificationsStream() {
    final trainerId = _supabase.auth.currentUser?.id;

    return _supabase
        .from('trainer_notifications')
        .stream(primaryKey: ['id'])
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false)
        .map((data) => data
        .map((item) => TrainerNotification(
      id: item['id'],
      trainerId: item['trainer_id'],
      type: NotificationType.values.firstWhere(
            (e) => e.toString().contains(item['type']),
        orElse: () => NotificationType.system,
      ),
      title: item['title'],
      message: item['message'],
      receiptId: item['receipt_id'],
      read: item['read'] ?? false,
      createdAt: DateTime.parse(item['created_at']),
    ))
        .toList());
  }

  // Отметить уведомление как прочитанное
  Future<void> markNotificationAsRead(String notificationId) async {
    await _supabase
        .from('trainer_notifications')
        .update({'read': true})
        .eq('id', notificationId)
        .execute();
  }

  // Получить все чеки для тренера
  Future<List<PaymentReceipt>> getPaymentReceipts() async {
    final trainerId = _supabase.auth.currentUser?.id;

    final response = await _supabase
        .from('payment_receipts')
        .select()
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false)
        .execute();

    return response.data.map((item) => PaymentReceipt(
      id: item['id'],
      clientId: item['client_id'],
      trainerId: item['trainer_id'],
      trainingId: item['training_id'],
      receiptImageUrl: item['receipt_image_url'],
      amount: item['amount']?.toDouble(),
      status: ReceiptStatus.values.firstWhere(
            (e) => e.toString().contains(item['status']),
        orElse: () => ReceiptStatus.pending,
      ),
      createdAt: DateTime.parse(item['created_at']),
    )).toList();
  }

  // Изменить статус чека
  Future<void> updateReceiptStatus({
    required String receiptId,
    required ReceiptStatus status,
  }) async {
    await _supabase
        .from('payment_receipts')
        .update({
      'status': status.toString().split('.').last,
      'verified_at': status == ReceiptStatus.approved
          ? DateTime.now().toIso8601String()
          : null,
    })
        .eq('id', receiptId)
        .execute();
  }
}