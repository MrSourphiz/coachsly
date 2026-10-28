import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/domain/entities/body_measurement.dart';
import 'package:formeo/domain/repositories/body_measurements_repository.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/ui/widgets/demo_pro_banner.dart';

// =============================================================================
// BodyMeasurementsSection — содержимое вкладки «Замеры» карточки клиента.
//
//   • актуальные параметры (последнее известное значение по каждому полю,
//     рост берётся из самой свежей записи, где он есть);
//   • изменение относительно предыдущего замера — если записей ≥ 2;
//   • график динамики по выбранному параметру и история замеров;
//   • кнопка «Запросить замеры» — бот сразу шлёт клиенту опрос.
//
// Плановый опрос раз в 30 дней шлёт крон body-measurements-monthly.
//
// Доступ:
//   • только тариф Pro — без Pro секция не рендерится и ничего не грузит
//     (тот же User.isPro, что закрывает вкладку «Тренировки»);
//     на сервере то же правило — public.trainer_has_pro();
//     исключение — демо-клиенты: на них секцию видят все (в т.ч. на триале),
//     чтобы показать фичу; данные заполняет seed_demo_body_measurements(),
//     запрос в Telegram для демо не отправляется;
//   • только тренер этого клиента — RLS по telegram_clients.trainer_id,
//     edge function проверяет владельца перед отправкой запроса.
// =============================================================================

/// Публичная обёртка: решает, показывать ли секцию вообще.
class BodyMeasurementsSection extends StatelessWidget {
  final String clientId;
  final bool isDemo;
  const BodyMeasurementsSection({
    super.key,
    required this.clientId,
    this.isDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = GetIt.instance<UserProvider>().user?.isPro ?? false;
    if (!isPro && !isDemo) return const SizedBox.shrink();
    return _BodyMeasurementsSectionBody(
      clientId: clientId,
      isDemo: isDemo,
      isPro: isPro,
    );
  }
}

// Держи синхронно с TRAINER_RESEND_COOLDOWN_HOURS в body-measurements/index.ts
const int kMeasurementResendCooldownHours = 24;

const _kAccent = Color(0xFF64B5F6);
// Нейтральные цвета направления (без оценки «хорошо/плохо»)
const _kDown = Color(0xFF81D4FA);
const _kUp = Color(0xFFCE93D8);

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _fmtDelta(double d) {
  final r = (d * 10).round() / 10;
  if (r == 0) return '0';
  return '${r > 0 ? '+' : '−'}${_fmt(r.abs())}';
}

class _BodyMeasurementsSectionBody extends StatefulWidget {
  final String clientId;
  final bool isDemo;
  final bool isPro;
  const _BodyMeasurementsSectionBody({
    required this.clientId,
    required this.isDemo,
    required this.isPro,
  });

  @override
  State<_BodyMeasurementsSectionBody> createState() => _BodyMeasurementsSectionState();
}

class _BodyMeasurementsSectionState extends State<_BodyMeasurementsSectionBody> {
  final _repo = GetIt.instance<BodyMeasurementsRepository>();
  late Future<(List<BodyMeasurement>, BodyMeasurementRequest?)> _future;
  bool _requesting = false;
  BodyMetric _chartMetric = BodyMetric.weight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final results = await Future.wait([
        _repo.getMeasurements(widget.clientId),
        _repo.getLatestRequest(widget.clientId),
      ]);
      return (
      results[0] as List<BodyMeasurement>,
      results[1] as BodyMeasurementRequest?,
      );
    }();
  }

  Future<void> _requestMeasurements() async {
    // Демо-клиент не существует в Telegram — объясняем, что произошло бы
    if (widget.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isPro
            ? 'Это демо-клиент. Настоящему клиенту бот сразу пришлёт опрос замеров в Telegram'
            : 'Это демо-клиент. Запрос замеров у настоящих клиентов доступен на тарифе Pro'),
      ));
      return;
    }
    setState(() => _requesting = true);
    final status = await _repo.requestMeasurements(widget.clientId);
    if (!mounted) return;

    final message = switch (status) {
      MeasurementRequestStatus.sent =>
      'Клиенту отправлен запрос замеров в Telegram',
      MeasurementRequestStatus.alreadyPending =>
      'Запрос уже отправлен недавно — ждём ответа клиента',
      MeasurementRequestStatus.clientBusy =>
      'Клиент сейчас проходит другой опрос в боте — попробуйте чуть позже',
      MeasurementRequestStatus.noTelegram =>
      'Клиент ещё не писал боту в Telegram',
      MeasurementRequestStatus.notPro =>
      'Замеры доступны на тарифе Pro',
      MeasurementRequestStatus.failed =>
      'Не удалось отправить запрос. Попробуйте позже',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    setState(() {
      _requesting = false;
      if (status == MeasurementRequestStatus.sent ||
          status == MeasurementRequestStatus.alreadyPending) {
        _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<BodyMeasurement>, BodyMeasurementRequest?)>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final measurements = snapshot.data?.$1 ?? const <BodyMeasurement>[];
        final request = snapshot.data?.$2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок не нужен — секция живёт на своей вкладке «Замеры».
            // Тренеру без Pro (видит только демо-клиента) поясняем, что это пример.
            if (!widget.isPro) ...[
              const DemoProBanner(),
              const SizedBox(height: 12),
            ],
            _RequestBar(
              request: loading ? null : request,
              latestMeasurementAt:
              measurements.isNotEmpty ? measurements.first.measuredAt : null,
              requesting: _requesting,
              onRequest: _requestMeasurements,
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              Text('Ошибка загрузки замеров: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (measurements.isEmpty)
                const _EmptyState()
              else ...[
                  _CurrentParams(measurements: measurements),
                  if (measurements.length >= 2) ...[
                    const SizedBox(height: 12),
                    _DynamicsCard(
                      measurements: measurements,
                      selected: _chartMetric,
                      onSelect: (m) => setState(() => _chartMetric = m),
                    ),
                    const SizedBox(height: 12),
                    _HistoryTile(measurements: measurements),
                  ],
                ],
          ],
        );
      },
    );
  }
}

// =============================================================================
// Статус запроса + кнопка «Запросить замеры»
// =============================================================================

class _RequestBar extends StatelessWidget {
  final BodyMeasurementRequest? request;
  final DateTime? latestMeasurementAt;
  final bool requesting;
  final VoidCallback onRequest;

  const _RequestBar({
    required this.request,
    required this.latestMeasurementAt,
    required this.requesting,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy');
    final r = request;
    final recentlySent = r != null &&
        r.isPending &&
        DateTime.now().difference(r.sentAt).inHours < kMeasurementResendCooldownHours;

    String status;
    IconData icon;
    if (r != null && r.isPending) {
      status = 'Запрос отправлен ${dateFmt.format(r.sentAt)}'
          '${r.source == 'cron' ? ' (плановый)' : ''} — ждём ответа клиента';
      icon = Icons.hourglass_top_rounded;
    } else if (r != null && r.status == 'expired') {
      status = 'Клиент не ответил на запрос от ${dateFmt.format(r.sentAt)}';
      icon = Icons.error_outline;
    } else if (latestMeasurementAt != null || r != null) {
      // Крон считает 30 дней от свежайшего из: последний замер / последний запрос
      final candidates = [latestMeasurementAt, r?.sentAt].whereType<DateTime>();
      final base = candidates.reduce((a, b) => a.isAfter(b) ? a : b);
      final next = base.add(const Duration(days: 30));
      status = next.isAfter(DateTime.now())
          ? 'Следующий плановый опрос ≈ ${dateFmt.format(next)}'
          : 'Плановый опрос уйдёт в ближайшие сутки';
      icon = Icons.event_repeat;
    } else {
      status = 'Бот опрашивает клиента раз в месяц автоматически';
      icon = Icons.event_repeat;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.colorWhite.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.colorWhite.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: (requesting || recentlySent) ? null : onRequest,
              icon: requesting
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.colorWhite))
                  : const Icon(Icons.straighten, size: 16),
              label: Text(recentlySent ? 'Отправлено' : 'Запросить замеры'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorDarkRed,
                foregroundColor: AppColors.colorWhite,
                disabledBackgroundColor: AppColors.colorWhite.withValues(alpha: 0.08),
                disabledForegroundColor: AppColors.colorWhite.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_weight_outlined,
              size: 22, color: AppColors.colorWhite.withValues(alpha: 0.45)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Замеров пока нет. Запросите их сейчас — клиент ответит боту '
                  'за пару минут, а динамика появится после второго замера.',
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.colorWhite.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Актуальные параметры
// =============================================================================

class _MetricSnapshot {
  final BodyMetric metric;
  final double value;
  final DateTime at;
  final double? delta; // относительно предыдущего замера с этим полем

  _MetricSnapshot(this.metric, this.value, this.at, this.delta);
}

List<_MetricSnapshot> _snapshots(List<BodyMeasurement> measurements) {
  final result = <_MetricSnapshot>[];
  for (final metric in BodyMetric.values) {
    final withValue = measurements.where((m) => m[metric] != null).toList();
    if (withValue.isEmpty) continue;
    final latest = withValue.first;
    final prev = withValue.length >= 2 ? withValue[1] : null;
    result.add(_MetricSnapshot(
      metric,
      latest[metric]!,
      latest.measuredAt,
      (prev != null && metric.trackable) ? latest[metric]! - prev[metric]! : null,
    ));
  }
  return result;
}

class _CurrentParams extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  const _CurrentParams({required this.measurements});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy');
    final latestDate = measurements.first.measuredAt;
    final snaps = _snapshots(measurements);

    double? valueOf(BodyMetric m) {
      for (final s in snaps) {
        if (s.metric == m) return s.value;
      }
      return null;
    }

    final h = valueOf(BodyMetric.height);
    final w = valueOf(BodyMetric.weight);
    final bmi = (h != null && w != null) ? w / math.pow(h / 100, 2) : null;

    final tiles = <Widget>[
      for (final s in snaps)
        _ParamTile(
          label: s.metric.label,
          value: _fmt(s.value),
          unit: s.metric.unit,
          delta: s.delta,
          // Значение не из последнего замера (клиент пропустил поле) — покажем дату
          staleDate: s.at == latestDate ? null : DateFormat('dd.MM').format(s.at),
        ),
      if (bmi != null)
        _ParamTile(label: 'ИМТ', value: bmi.toStringAsFixed(1), unit: _bmiLabel(bmi)),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Актуальные',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
              const Spacer(),
              Text('замер от ${dateFmt.format(latestDate)}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
            ],
          ),
          if (measurements.length >= 2) ...[
            const SizedBox(height: 2),
            Text('изменение — к предыдущему замеру',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            const spacing = 8.0;
            final columns = c.maxWidth >= 520 ? 4 : 3;
            final tileWidth = (c.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: tiles.map((t) => SizedBox(width: tileWidth, child: t)).toList(),
            );
          }),
        ],
      ),
    );
  }

  static String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'дефицит';
    if (bmi < 25) return 'норма';
    if (bmi < 30) return 'избыток';
    return 'ожирение';
  }
}

class _ParamTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double? delta;
  final String? staleDate;

  const _ParamTile({
    required this.label,
    required this.value,
    required this.unit,
    this.delta,
    this.staleDate,
  });

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final rounded = d == null ? null : (d * 10).round() / 10;
    // Цвет нейтральный: «вниз» хорошо для талии при похудении,
    // но плохо для бицепса при наборе — оценку оставляем тренеру.
    final deltaColor = rounded == null || rounded == 0
        ? AppColors.colorGrey
        : (rounded < 0 ? _kDown : _kUp);
    final arrow = rounded == null || rounded == 0 ? '' : (rounded < 0 ? '▼ ' : '▲ ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.colorGrey)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.colorWhite)),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.colorGrey)),
              ),
            ],
          ),
          if (rounded != null)
            Text(
              rounded == 0 ? 'без изменений' : '$arrow${_fmtDelta(rounded)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: deltaColor),
            )
          else if (staleDate != null)
            Text('от $staleDate',
                style: TextStyle(fontSize: 11, color: AppColors.colorGrey.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// =============================================================================
// Динамика: выбор параметра + график + итог за весь период
// =============================================================================

class _DynamicsCard extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  final BodyMetric selected;
  final ValueChanged<BodyMetric> onSelect;

  const _DynamicsCard({
    required this.measurements,
    required this.selected,
    required this.onSelect,
  });

  List<(DateTime, double)> _series(BodyMetric m) => measurements.reversed
      .where((e) => e[m] != null)
      .map((e) => (e.measuredAt, e[m]!))
      .toList();

  @override
  Widget build(BuildContext context) {
    // Только параметры, по которым есть хотя бы 2 точки
    final available = BodyMetric.values
        .where((m) => m.trackable && _series(m).length >= 2)
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();

    final metric = available.contains(selected) ? selected : available.first;
    final series = _series(metric);
    final first = series.first;
    final last = series.last;
    final total = last.$2 - first.$2;
    final dateFmt = DateFormat('dd.MM.yyyy');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Динамика',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: available.map((m) {
                final isSel = m == metric;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onSelect(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? _kAccent.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel ? _kAccent : AppColors.colorWhite.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(m.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                            color: isSel ? _kAccent : AppColors.colorWhite.withValues(alpha: 0.7),
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(painter: _LineChartPainter(series, metric.unit)),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: AppColors.colorWhite.withValues(alpha: 0.7)),
              children: [
                TextSpan(text: 'С ${dateFmt.format(first.$1)}: '),
                TextSpan(
                  text: '${_fmt(first.$2)} → ${_fmt(last.$2)} ${metric.unit}  '
                      '(${_fmtDelta(total)})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.colorWhite),
                ),
                TextSpan(text: ' · замеров: ${series.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<(DateTime, double)> points;
  final String unit;

  _LineChartPainter(this.points, this.unit);

  static const _leftPad = 40.0;
  static const _bottomPad = 20.0;
  static const _topPad = 16.0;
  static const _rightPad = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.$2).toList();
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    // Небольшой запас по краям; ровная линия не должна прилипать к оси
    final span = maxV - minV;
    final pad = span == 0 ? math.max(1.0, maxV * 0.02) : span * 0.15;
    minV -= pad;
    maxV += pad;

    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    final tSpan = t1 - t0 == 0 ? 1.0 : t1 - t0;

    final chart = Rect.fromLTRB(
        _leftPad, _topPad, size.width - _rightPad, size.height - _bottomPad);

    Offset toOffset((DateTime, double) p) => Offset(
      chart.left + (p.$1.millisecondsSinceEpoch - t0) / tSpan * chart.width,
      chart.bottom - (p.$2 - minV) / (maxV - minV) * chart.height,
    );

    // Сетка + подписи оси Y
    final gridPaint = Paint()
      ..color = AppColors.colorWhite.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final v = maxV - (maxV - minV) * i / 3;
      _text(canvas, _fmt((v * 10).round() / 10), Offset(0, y - 6),
          width: _leftPad - 6, align: TextAlign.right, alpha: 0.45);
    }

    final offsets = points.map(toOffset).toList();

    // Заливка под линией
    final fill = Path()..moveTo(offsets.first.dx, chart.bottom);
    for (final o in offsets) {
      fill.lineTo(o.dx, o.dy);
    }
    fill
      ..lineTo(offsets.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kAccent.withValues(alpha: 0.25), _kAccent.withValues(alpha: 0)],
        ).createShader(chart),
    );

    // Линия
    final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = _kAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Точки
    for (final o in offsets) {
      canvas.drawCircle(o, 3.5, Paint()..color = AppColors.colorLightBlue);
      canvas.drawCircle(
          o,
          3.5,
          Paint()
            ..color = _kAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Подпись последнего значения
    final lastO = offsets.last;
    _text(canvas, '${_fmt(points.last.$2)} $unit',
        Offset(math.min(lastO.dx - 30, chart.right - 60), math.max(0.0, lastO.dy - 20)),
        width: 60, align: TextAlign.center, alpha: 1, bold: true);

    // Подписи оси X: первая и последняя даты (+ средняя, если места хватает)
    final df = DateFormat('dd.MM');
    _text(canvas, df.format(points.first.$1), Offset(chart.left - 16, chart.bottom + 5),
        width: 40, align: TextAlign.center, alpha: 0.45);
    _text(canvas, df.format(points.last.$1), Offset(chart.right - 24, chart.bottom + 5),
        width: 40, align: TextAlign.center, alpha: 0.45);
    if (points.length >= 3 && chart.width > 200) {
      final mid = points[points.length ~/ 2];
      final mo = toOffset(mid);
      _text(canvas, df.format(mid.$1), Offset(mo.dx - 20, chart.bottom + 5),
          width: 40, align: TextAlign.center, alpha: 0.45);
    }
  }

  void _text(Canvas canvas, String s, Offset at,
      {required double width, TextAlign align = TextAlign.left, double alpha = 1, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: AppColors.colorWhite.withValues(alpha: alpha),
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.points != points || old.unit != unit;
}

// =============================================================================
// История замеров
// =============================================================================

class _HistoryTile extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  const _HistoryTile({required this.measurements});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy');
    // Колонки — только те параметры, что хоть раз заполнялись
    final metrics = BodyMetric.values
        .where((m) => measurements.any((e) => e[m] != null))
        .toList();

    TextStyle head = const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.colorGrey);
    TextStyle cell = const TextStyle(fontSize: 12, color: AppColors.colorWhite);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text('История замеров (${measurements.length})',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  TableRow(children: [
                    _pad(Text('Дата', style: head)),
                    for (final m in metrics) _pad(Text('${m.label}, ${m.unit}', style: head)),
                  ]),
                  for (final e in measurements)
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                      ),
                      children: [
                        _pad(Text(dateFmt.format(e.measuredAt), style: cell)),
                        for (final m in metrics)
                          _pad(Text(e[m] != null ? _fmt(e[m]!) : '—',
                              style: cell.copyWith(
                                  color: e[m] != null ? null : AppColors.colorGrey))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(0, 7, 16, 7), child: child);
}