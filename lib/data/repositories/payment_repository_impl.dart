import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/entities/payment_model.dart';
import 'package:formeo/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final SupabaseDataSource _dataSource;

  PaymentRepositoryImpl(this._dataSource);

  @override
  Future<Payment?> getPaymentById(String paymentId) async {
    final json = await _dataSource.getPaymentById(paymentId);
    if (json == null) return null;
    return Payment.fromJson(json);
  }

  @override
  Future<Payment?> getPaymentByBookingId(String bookingId) async {
    final json = await _dataSource.getPaymentByBookingId(bookingId);
    if (json == null) return null;
    return Payment.fromJson(json);
  }

  @override
  Future<Map<String, String?>> getReceiptPathsForBookings(List<String> bookingIds) async {
    return await _dataSource.getReceiptPathsForBookings(bookingIds);
  }

  @override
  Future<String?> getReceiptSignedUrl(String storagePath) async {
    return await _dataSource.getReceiptSignedUrl(storagePath);
  }
}
