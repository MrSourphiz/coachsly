import 'package:formeo/domain/entities/body_measurement.dart';

abstract class BodyMeasurementsRepository {
  /// Все замеры клиента, новые первыми.
  Future<List<BodyMeasurement>> getMeasurements(String clientId, {int limit = 36});

  /// Последний отправленный клиенту запрос замеров (или null).
  Future<BodyMeasurementRequest?> getLatestRequest(String clientId);

  /// Отправляет клиенту в Telegram запрос на новые замеры
  /// (edge-функция body-measurements, type: request).
  Future<MeasurementRequestStatus> requestMeasurements(String clientId);
}
