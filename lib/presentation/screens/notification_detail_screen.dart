import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/domain/repositories/payment_repository.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotificationItem notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  // ✅ Future кэшируется в initState — при перестройке виджета
  // не создаётся новый запрос к БД
  Future<String?>? _receiptUrlFuture;

  @override
  void initState() {
    super.initState();
    final paymentId = widget.notification.payload['payment_id'] as String?;
    if (paymentId != null &&
        widget.notification.type.toLowerCase() == 'payment_receipt') {
      _receiptUrlFuture = _getReceiptUrl(paymentId);
    }
  }

  Future<String?> _getReceiptUrl(String paymentId) async {
    final repo = GetIt.instance<PaymentRepository>();
    final payment = await repo.getPaymentById(paymentId);
    if (payment?.receiptPhotoUrl == null || payment!.receiptPhotoUrl!.isEmpty) {
      return null;
    }
    return repo.getReceiptSignedUrl(payment.receiptPhotoUrl!);
  }

  String _titleByType(String type) {
    switch (type.toLowerCase()) {
      case 'payment_receipt': return 'Чек оплаты';
      case 'new_client': return 'Новый клиент';
      case 'trainer_no_response': return 'Клиент не ответил';
      case 'retention_signal': return 'Сигнал удержания';
      case 'progress_report_sent': return 'Прогресс-срез отправлен';
      default: return 'Уведомление';
    }
  }

  String _reasonLabel(String? reason) {
    const labels = {
      'missed_2_sessions': '2 пропуска подряд',
      'low_wellbeing_twice': 'Оценка самочувствия 1–2 дважды подряд',
      'attendance_below_50': 'Посещаемость < 50% за 2 недели',
    };
    return labels[reason] ?? (reason ?? '—');
  }

  String _sessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'single': return 'Разовая тренировка';
      case 'block': return 'Тренировочный блок';
      case 'subscription': return 'Абонемент';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleByType(widget.notification.type)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd.MM.yyyy HH:mm')
                  .format(widget.notification.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (widget.notification.type.toLowerCase()) {
      case 'payment_receipt': return _buildPaymentReceipt(context);
      case 'new_client': return _buildNewClient(context);
      case 'trainer_no_response': return _buildNoResponse(context);
      case 'retention_signal': return _buildRetentionSignal(context);
      case 'progress_report_sent': return _buildProgressReportSent(context);
      default: return _buildUnknown(context);
    }
  }

  Widget _buildPaymentReceipt(BuildContext context) {
    final p = widget.notification.payload;
    final amount = p['amount'];
    final clientName = p['client_name'] ?? 'Неизвестно';
    final purchaseType = _sessionTypeLabel(p['purchase_type'] ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(context, Icons.person, 'Клиент', clientName),
        const SizedBox(height: 16),
        _buildInfoRow(
            context, Icons.fitness_center, 'Тип тренировки', purchaseType),
        const SizedBox(height: 16),
        _buildInfoRow(context, Icons.payments, 'Сумма', '$amount ₽'),
        const SizedBox(height: 24),
        if (_receiptUrlFuture != null)
          FutureBuilder<String?>(
            future: _receiptUrlFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Ошибка загрузки чека',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              final url = snapshot.data;
              if (url == null || url.isEmpty) {
                return Text(
                  'Фото чека недоступно',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фото чека',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, _) => Text(
                        'Не удалось загрузить фото',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildNoResponse(BuildContext context) {
    final p = widget.notification.payload;
    final clientName = p['client_name'] ?? 'Неизвестно';
    final scheduledAtRaw = p['scheduled_at'] as String?;

    String scheduledAtFormatted = '—';
    if (scheduledAtRaw != null) {
      try {
        scheduledAtFormatted = DateFormat('dd.MM.yyyy HH:mm')
            .format(DateTime.parse(scheduledAtRaw).toLocal());
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF7A3D00).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7A3D00).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_off_outlined,
                  color: Color(0xFFFFDDB3), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Клиент не ответил на напоминание о тренировке',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFDDB3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoRow(context, Icons.person, 'Клиент', clientName),
        const SizedBox(height: 16),
        _buildInfoRow(
            context, Icons.calendar_today, 'Дата тренировки', scheduledAtFormatted),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Что можно сделать',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Свяжитесь с клиентом напрямую, чтобы уточнить — придёт ли он на тренировку. Если нет — отмените занятие в расписании.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewClient(BuildContext context) {
    final p = widget.notification.payload;
    final firstName = p['first_name'] ?? '';
    final lastName = p['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    return _buildInfoRow(context, Icons.person, 'Имя клиента', fullName);
  }

  Widget _buildRetentionSignal(BuildContext context) {
    final p = widget.notification.payload;
    final signalLevel = p['signal_level'] as String?;
    final reason = p['reason'] as String?;
    final isRed = signalLevel == 'red';

    final title = (p['title'] as String?)?.trim();
    final body = (p['body'] as String?)?.trim();

    final bannerColor = isRed ? const Color(0xFF991B1B) : const Color(0xFF7A3D00);
    final bannerTextColor = isRed ? const Color(0xFFFFD1D1) : const Color(0xFFFFDDB3);
    final bannerIcon = isRed ? Icons.report_gmailerrorred_rounded : Icons.warning_amber_rounded;

    final fallbackBody = isRed
        ? 'Клиент под риском ухода — требуется внимание'
        : 'Клиент начинает пропускать тренировки';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bannerColor.withOpacity(0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(bannerIcon, color: bannerTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (body != null && body.isNotEmpty) ? body : fallbackBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: bannerTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoRow(
          context,
          Icons.flag_outlined,
          'Уровень сигнала',
          isRed ? 'Красный — высокий риск' : 'Жёлтый — начинается снижение',
        ),
        const SizedBox(height: 16),
        _buildInfoRow(context, Icons.info_outline, 'Причина', _reasonLabel(reason)),
        if (title != null && title.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildInfoRow(context, Icons.title, 'Заголовок', title),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Что можно сделать',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRed
                    ? 'Свяжитесь с клиентом лично — уточните причину пропусков или низкого самочувствия и предложите поддержку, чтобы не потерять клиента.'
                    : 'Понаблюдайте за посещаемостью клиента в ближайшие тренировки. Лёгкое напоминание или сообщение поддержки может предотвратить дальнейшее снижение.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressReportSent(BuildContext context) {
    final p = widget.notification.payload;
    final body = (p['body'] as String?)?.trim();
    final clientName = (p['client_name'] as String?)?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.insights_rounded,
                  color: Theme.of(context).colorScheme.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (body != null && body.isNotEmpty)
                      ? body
                      : 'Клиенту отправлена сводка прогресса за 4 недели',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (clientName != null && clientName.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildInfoRow(context, Icons.person, 'Клиент', clientName),
        ],
      ],
    );
  }

  Widget _buildUnknown(BuildContext context) {
    return Text(
      widget.notification.payload.toString(),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
