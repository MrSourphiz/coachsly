import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:formeo/domain/entities/body_measurement.dart';
import 'package:formeo/domain/repositories/body_measurements_repository.dart';

class BodyMeasurementsRepositoryImpl implements BodyMeasurementsRepository {
  final SupabaseClient _client;

  BodyMeasurementsRepositoryImpl(this._client);

  @override
  Future<List<BodyMeasurement>> getMeasurements(String clientId, {int limit = 36}) async {
    try {
      final data = await _client
          .from('client_body_measurements')
          .select('id, client_id, measured_at, source, '
              'height_cm, weight_kg, chest_cm, waist_cm, hips_cm, biceps_cm, thigh_cm')
          .eq('client_id', clientId)
          .order('measured_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BodyMeasurementsRepository.getMeasurements error: $e');
      rethrow;
    }
  }

  @override
  Future<BodyMeasurementRequest?> getLatestRequest(String clientId) async {
    try {
      final data = await _client
          .from('body_measurement_requests')
          .select('id, source, status, sent_at, completed_at')
          .eq('client_id', clientId)
          .neq('status', 'failed')
          .order('sent_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data == null ? null : BodyMeasurementRequest.fromJson(data);
    } catch (e) {
      debugPrint('BodyMeasurementsRepository.getLatestRequest error: $e');
      return null;
    }
  }

  @override
  Future<MeasurementRequestStatus> requestMeasurements(String clientId) async {
    try {
      final response = await _client.functions.invoke(
        'body-measurements',
        body: {'type': 'request', 'client_id': clientId},
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      debugPrint('body-measurements request: status=${response.status}, data=$data');
      return MeasurementRequestStatus.parse(data['status'] as String?);
    } on FunctionException catch (e) {
      // Не-2xx (403 not_pro, 404 not_found) supabase_flutter бросает исключением —
      // статус лежит в теле ответа
      debugPrint('body-measurements request: status=${e.status}, details=${e.details}');
      final details = e.details;
      return MeasurementRequestStatus.parse(
          details is Map ? details['status'] as String? : null);
    } catch (e) {
      debugPrint('BodyMeasurementsRepository.requestMeasurements error: $e');
      return MeasurementRequestStatus.failed;
    }
  }
}
