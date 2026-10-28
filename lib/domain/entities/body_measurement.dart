/// Параметры тела, которые собирает бот. Порядок = порядок отображения.
/// Ключи (column) совпадают с колонками client_body_measurements.
enum BodyMetric {
  weight('weight_kg', 'Вес', 'кг'),
  height('height_cm', 'Рост', 'см'),
  chest('chest_cm', 'Грудь', 'см'),
  waist('waist_cm', 'Талия', 'см'),
  hips('hips_cm', 'Бёдра', 'см'),
  biceps('biceps_cm', 'Бицепс', 'см'),
  thigh('thigh_cm', 'Бедро', 'см');

  final String column;
  final String label;
  final String unit;
  const BodyMetric(this.column, this.label, this.unit);

  /// Рост у взрослых не меняется — в динамике его не показываем.
  bool get trackable => this != BodyMetric.height;
}

class BodyMeasurement {
  final String id;
  final String clientId;
  final DateTime measuredAt;
  final String source; // 'bot' | 'trainer'
  final Map<BodyMetric, double?> values;

  const BodyMeasurement({
    required this.id,
    required this.clientId,
    required this.measuredAt,
    required this.source,
    required this.values,
  });

  double? operator [](BodyMetric m) => values[m];

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      measuredAt: DateTime.parse(json['measured_at'] as String).toLocal(),
      source: json['source'] as String? ?? 'bot',
      values: {
        for (final m in BodyMetric.values) m: (json[m.column] as num?)?.toDouble(),
      },
    );
  }
}

/// Последний запрос замеров, отправленный клиенту (кроном или тренером).
class BodyMeasurementRequest {
  final String id;
  final String source; // 'cron' | 'trainer'
  final String status; // pending | completed | expired | superseded | failed
  final DateTime sentAt;
  final DateTime? completedAt;

  const BodyMeasurementRequest({
    required this.id,
    required this.source,
    required this.status,
    required this.sentAt,
    this.completedAt,
  });

  bool get isPending => status == 'pending';

  factory BodyMeasurementRequest.fromJson(Map<String, dynamic> json) {
    return BodyMeasurementRequest(
      id: json['id'] as String,
      source: json['source'] as String,
      status: json['status'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String).toLocal()
          : null,
    );
  }
}

/// Результат нажатия «Запросить замеры».
enum MeasurementRequestStatus {
  sent,
  alreadyPending,
  clientBusy,
  noTelegram,
  notPro,
  failed;

  static MeasurementRequestStatus parse(String? raw) {
    switch (raw) {
      case 'sent':
        return MeasurementRequestStatus.sent;
      case 'already_pending':
        return MeasurementRequestStatus.alreadyPending;
      case 'client_busy':
        return MeasurementRequestStatus.clientBusy;
      case 'no_telegram':
        return MeasurementRequestStatus.noTelegram;
      case 'not_pro':
        return MeasurementRequestStatus.notPro;
      default:
        return MeasurementRequestStatus.failed;
    }
  }
}
