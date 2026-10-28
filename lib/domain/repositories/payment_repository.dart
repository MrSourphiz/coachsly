import 'package:formeo/domain/entities/payment_model.dart';

// domain/repositories/payment_repository.dart
abstract class PaymentRepository {
  Future<Payment?> getPaymentById(String paymentId);
  Future<Payment?> getPaymentByBookingId(String bookingId);
  Future<Map<String, String?>> getReceiptPathsForBookings(List<String> bookingIds); // ← пакетная загрузка
  Future<String?> getReceiptSignedUrl(String storagePath);
}
