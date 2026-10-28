import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/repositories/payment_repository.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/presentation/screens/add_schedule_entry_screen.dart';
import 'package:formeo/ui/widgets/custom_app_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final String trainerId;
  late final ClientBloc clientBloc;
  List<Client> clientsList = [];
  StreamSubscription? _clientSubscription;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ValueNotifier<Map<DateTime, List<Schedule>>> _eventsNotifier =
  ValueNotifier({});

  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isCopying = false;

  // ── Кэш путей к чекам: booking_id -> receipt_photo_url (или null, если чека нет) ──
  final Map<String, String?> _receiptPaths = {};
  final Set<String> _loadedReceiptBookingIds = {};

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Schedule> _getEventsForDay(DateTime day) {
    final map = _eventsNotifier.value;
    return map[_normalizeDate(day)] ?? [];
  }

  bool get _isCurrentWeekSelected {
    final now = DateTime.now();
    final thisMonday = _startOfWeek(now);
    final thisSunday = thisMonday.add(const Duration(days: 6));
    final selected = _normalizeDate(_selectedDay ?? now);
    return !selected.isBefore(thisMonday) && !selected.isAfter(thisSunday);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    final user = GetIt.instance<UserProvider>().user!;
    trainerId = user.id;

    clientBloc = GetIt.instance<ClientBloc>();

    if (clientBloc.state is ClientLoaded) {
      clientsList = (clientBloc.state as ClientLoaded).clients;
    }

    _clientSubscription = clientBloc.stream.listen((state) {
      if (state is ClientLoaded && mounted) {
        setState(() => clientsList = state.clients);
      }
    });

    if (clientsList.isEmpty) {
      clientBloc.add(SubscribeClients(trainerId));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheduleState = context.read<ScheduleBloc>().state;
      if (scheduleState is ScheduleSuccess) {
        _updateEvents(scheduleState.schedules);
      } else {
        context.read<ScheduleBloc>().add(SubscribeSchedules(trainerId));
      }
    });
  }

  @override
  void dispose() {
    _clientSubscription?.cancel();
    _eventsNotifier.dispose();
    super.dispose();
  }

  // ───── Утилиты ─────

  DateTime _startOfWeek(DateTime date) {
    final diff = date.weekday - 1;
    return _normalizeDate(date.subtract(Duration(days: diff)));
  }

  // ───── Копирование недели ─────

  Future<void> _copyCurrentWeekToNext(List<Schedule> allSchedules) async {
    final now = DateTime.now();
    final thisMonday = _startOfWeek(now);
    final thisSunday = thisMonday.add(const Duration(days: 6));
    final nextMonday = thisMonday.add(const Duration(days: 7));
    final nextSunday = nextMonday.add(const Duration(days: 6));

    final thisWeek = allSchedules.where((s) {
      final local = _normalizeDate(s.scheduledAt.toLocal());
      final status = s.status.toLowerCase();
      return !local.isBefore(thisMonday) &&
          !local.isAfter(thisSunday) &&
          status != 'canceled' &&
          status != 'rescheduled';
    }).toList();

    if (thisWeek.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('На текущей неделе нет тренировок для копирования'),
          ),
        );
      }
      return;
    }

    final nextWeekExists = allSchedules.any((s) {
      final local = _normalizeDate(s.scheduledAt.toLocal());
      return !local.isBefore(nextMonday) && !local.isAfter(nextSunday);
    });

    if (nextWeekExists) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Тренировки уже есть'),
          content: const Text(
            'На следующей неделе уже есть тренировки. Добавить ещё?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isCopying = true);

    final user = GetIt.instance<UserProvider>().user!;
    final tzName = user.timezone;
    int successCount = 0;

    try {
      for (final s in thisWeek) {
        final localOriginal = s.scheduledAt.toLocal();
        final localNew = DateTime(
          localOriginal.year,
          localOriginal.month,
          localOriginal.day + 7,
          localOriginal.hour,
          localOriginal.minute,
        );

        final location = tz.getLocation(tzName);
        final tzDateTime = tz.TZDateTime.from(localNew, location);
        final utc = tzDateTime.toUtc();

        final newSchedule = Schedule(
          scheduledAt: utc,
          timezone: tzName,
          trainerId: trainerId,
          clientId: s.clientId,
          sessionType: s.sessionType,
          status: 'scheduled',
          workoutPlanId: null,
          workoutDayNumber: null,
          description: s.description,
        );

        try {
          await context
              .read<ScheduleBloc>()
              .bookSession
              .execute(newSchedule);
          successCount++;
        } catch (e) {
          debugPrint('Ошибка копирования тренировки ${s.id}: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount == thisWeek.length
                  ? 'Скопировано $successCount тренировок на следующую неделю'
                  : 'Скопировано $successCount из ${thisWeek.length} тренировок',
            ),
          ),
        );
        context.read<ScheduleBloc>().add(SubscribeSchedules(trainerId));
      }
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  // ───── Вспомогательные методы ─────

  /// Вычисляет «расширенный» статус записи для отображения на карточке.
  ///
  /// Порядок приоритетов:
  /// 1. past        — тренировка в прошлом (независимо от booking_state)
  /// 2. canceled / rescheduled / completed — финальные состояния
  /// 3. paid        — клиент подтвердил И оплатил (isPaid == true)
  /// 4. confirmed   — клиент подтвердил (без оплаты)
  /// 5. grace       — клиент ещё НЕ уведомлён о записи
  ///                  (isInGracePeriod == true, т.е. booking_created_notified_at IS NULL)
  ///                  Тренер в буфере — может отменить без последствий.
  /// 6. urgent      — уведомлён, но до тренировки ≤ 8 часов и нет ответа
  /// 7. awaiting24  — уведомлён, до тренировки ≤ 24 часа и нет ответа
  /// 8. scheduled   — стандартное ожидание (уведомлён, >24 часа до тренировки)
  String _resolvedStatus(Schedule s, {required bool isPast}) {
    if (isPast) return 'past';

    final bookingState = s.bookingState.toLowerCase();
    final confirmationState = s.confirmationState.toLowerCase();

    // Финальные статусы — не переопределяем
    if (bookingState == 'canceled') return 'canceled';
    if (bookingState == 'rescheduled') return 'rescheduled';
    if (bookingState == 'completed') return 'completed';

    // Клиент подтвердил
    if (confirmationState == 'confirmed') {
      return s.isPaid ? 'paid' : 'confirmed';
    }

    // grace-период — booking_created_notified_at ещё NULL.
    // При записи день в день ядро сразу ставит 24h/8h reminder,
    // клиент уже получил первый запрос подтверждения.
    // urgent (красный «не ответил») не подходит — клиент только что узнал.
    // Показываем awaiting24 для < 24ч, grace для остальных.
    if (s.isInGracePeriod) {
      final now = DateTime.now().toUtc();
      final hoursLeft = s.scheduledAt.difference(now).inMinutes / 60.0;
      if (hoursLeft <= 24) return 'awaiting24';
      return 'grace';
    }

    // Клиент уведомлён — проверяем временны́е окна
    final now = DateTime.now().toUtc();
    final hoursLeft = s.scheduledAt.difference(now).inMinutes / 60.0;

    if (confirmationState == 'no_response') {
      // no_response уже установлен бэкендом — показываем как urgent
      if (hoursLeft <= 8) return 'urgent';
      return 'no_response';
    }

    // Ещё ожидаем ответа (pending)
    if (hoursLeft <= 8) return 'urgent';
    if (hoursLeft <= 24) return 'awaiting24';

    return 'scheduled';
  }

  Color backgroundColorByStatus(String status, {required bool forceGrey}) {
    if (forceGrey) return const Color(0xFF374151);
    switch (status) {
      case 'paid':        return const Color(0xFF1A4D2E);
      case 'confirmed':   return const Color(0xFF256D47);
      case 'canceled':    return const Color(0xFF801A1A);
      case 'rescheduled': return const Color(0xFF1A3D80);
      case 'urgent':      return const Color(0xFF6B1A1A);
      case 'awaiting24':  return const Color(0xFF5A3E10);
      case 'grace':       return const Color(0xFF1E3A5F);
      case 'completed':   return const Color(0xFF374151);
      case 'past':        return const Color(0xFF374151);
      default:            return const Color(0xFF1C3A2E);
    }
  }

  IconData iconByStatus(String status) {
    switch (status) {
      case 'paid':        return Icons.payments_rounded;
      case 'confirmed':   return Icons.check_circle;
      case 'canceled':    return Icons.cancel;
      case 'completed':   return Icons.fitness_center;
      case 'urgent':      return Icons.warning_amber_rounded;
      case 'awaiting24':  return Icons.mark_chat_unread_outlined;
      case 'grace':       return Icons.hourglass_top_rounded;
      case 'rescheduled': return Icons.swap_horiz_rounded;
      case 'past':        return Icons.history;
      default:            return Icons.notifications_active_outlined;
    }
  }

  String textByStatus(String status) {
    switch (status) {
      case 'paid':        return 'Клиент подтвердил и оплатил';
      case 'confirmed':   return 'Клиент подтвердил тренировку';
      case 'canceled':    return 'Тренировка отменена';
      case 'completed':   return 'Тренировка выполнена';
      case 'rescheduled': return 'Тренировка перенесена';
      case 'no_response': return 'Клиент не ответил на напоминание';
      case 'urgent':      return 'Клиент не ответил · повторный запрос (8ч)';
      case 'awaiting24':  return 'Запрос подтверждения отправлен (24ч)';
      case 'grace':       return 'Буферное время · уведомление ещё не отправлено';
      case 'past':        return 'Тренировка прошла';
      default:            return 'Уведомление отправлено клиенту';
    }
  }

  Color textColorByStatus(String status) {
    switch (status) {
      case 'paid':        return const Color(0xFF90EEC4);
      case 'confirmed':   return const Color(0xFFD2FFE0);
      case 'canceled':    return const Color(0xFFFFCCCC);
      case 'rescheduled': return const Color(0xFFCCDDFF);
      case 'urgent':      return const Color(0xFFFFCCCC);
      case 'awaiting24':  return const Color(0xFFFFDDB3);
      case 'grace':       return const Color(0xFFBFD7F7);
      case 'completed':   return Colors.white70;
      case 'past':        return Colors.white70;
      default:            return const Color(0xFFB2DFCC);
    }
  }

  String _pluralizeSession(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) return '$count занятий';
    if (mod10 == 1) return '$count занятие';
    if (mod10 >= 2 && mod10 <= 4) return '$count занятия';
    return '$count занятий';
  }

  String textBySessionType(String sessionType) {
    switch (sessionType.toLowerCase()) {
      case 'single':
        return 'Разовая тренировка';
      case 'block':
        return 'Тренировка из тренировочного блока';
      case 'subscription':
        return 'Тренировка по абонементу';
      default:
        return 'Консультация';
    }
  }

  /// Для тренировок из блока добавляет порядковый номер:
  /// "Тренировка из тренировочного блока · 2 из 3"
  String _sessionTypeLabel(Schedule schedule) {
    final base = textBySessionType(schedule.sessionType);
    if (schedule.sessionType.toLowerCase() == 'block' &&
        schedule.blockSessionNumber != null &&
        schedule.blockTotalSessions != null) {
      return '$base · ${schedule.blockSessionNumber} из ${schedule.blockTotalSessions}';
    }
    return base;
  }

  String clientById(String clientId) {
    final index = clientsList.indexWhere((c) => c.id == clientId);
    if (index == -1) return 'Неизвестно';
    return clientsList[index].firstName;
  }

  Widget _buildKettlebellIndicator(int count) {
    if (count == 0) return const SizedBox(height: 12);

    int displayCount = count;
    bool showPlus = false;

    if (count >= 4) {
      displayCount = 3;
      showPlus = true;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SvgPicture.asset(
              'assets/images/icon-kettlebell.svg',
              width: 10,
              height: 10,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.secondary,
                BlendMode.srcIn,
              ),
            ),
          ),
        if (showPlus)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '+',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell({
    required DateTime day,
    required int eventsCount,
    required Color textColor,
    Color? bgColor,
    BoxBorder? border,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor ?? Colors.transparent,
              border: border,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                height: 1,
              ),
            ),
          ),
          SizedBox(
            height: 12,
            child: _buildKettlebellIndicator(eventsCount),
          ),
        ],
      ),
    );
  }

  void _updateEvents(List<Schedule> schedules) {
    final Map<DateTime, List<Schedule>> newEvents = {};
    for (var schedule in schedules) {
      final localDate = schedule.scheduledAt.toLocal();
      final normalized = _normalizeDate(localDate);
      newEvents.putIfAbsent(normalized, () => []);
      newEvents[normalized]!.add(schedule.copyWith(scheduledAt: localDate));
    }
    for (var day in newEvents.keys) {
      newEvents[day]!.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }
    _eventsNotifier.value = newEvents;
  }

  Future<void> _confirmAction(Schedule schedule) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Что сделать с тренировкой?'),
        content: Text('Тренировка клиента ${clientById(schedule.clientId)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reschedule'),
            child: const Text('Перенести'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Отменить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == null) return;

    if (action == 'reschedule') {
      await _showReschedulePicker(schedule);
    } else if (action == 'cancel') {
      context.read<ScheduleBloc>().add(CancelSchedule(schedule.id!, trainerId));
    } else if (action == 'delete') {
      context.read<ScheduleBloc>().add(DeleteSchedule(schedule.id!));
    }
  }

  Future<void> _showReschedulePicker(Schedule schedule) async {
    final originalLocal = schedule.scheduledAt.toLocal();
    DateTime pickedDate = _normalizeDate(originalLocal);
    TimeOfDay pickedTime = TimeOfDay(
      hour: originalLocal.hour,
      minute: originalLocal.minute,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final dateStr =
              '${pickedDate.day.toString().padLeft(2, '0')}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}';
          final timeStr =
              '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: const Text('Перенести тренировку'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Дата
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(dateStr),
                  onTap: () async {
                    final today = DateTime.now();
                    final first = DateTime(today.year, today.month, today.day);
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate.isBefore(first) ? first : pickedDate,
                      firstDate: first,
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setS(() => pickedDate = d);
                  },
                ),
                // Время
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(timeStr),
                  onTap: () async {
                    TimeOfDay tempTime = pickedTime;
                    await showDialog(
                      context: ctx,
                      builder: (dialogCtx) => StatefulBuilder(
                        builder: (dialogCtx, setD) => AlertDialog(
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          content: SizedBox(
                            height: 240,
                            width: 300,
                            child: Column(
                              children: [
                                Expanded(
                                  child: CupertinoTheme(
                                    data: const CupertinoThemeData(
                                        brightness: Brightness.light),
                                    child: CupertinoDatePicker(
                                      mode: CupertinoDatePickerMode.time,
                                      use24hFormat: true,
                                      initialDateTime: DateTime(
                                        2025, 1, 1,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      ),
                                      onDateTimeChanged: (dt) {
                                        tempTime = TimeOfDay(
                                            hour: dt.hour, minute: dt.minute);
                                      },
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx),
                                        child: const Text('Отмена'),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () {
                                          setS(() => pickedTime = tempTime);
                                          Navigator.pop(dialogCtx);
                                        },
                                        child: const Text('ОК'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Перенести'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || confirmed != true) return;

    final user = GetIt.instance<UserProvider>().user!;
    final location = tz.getLocation(user.timezone);
    final newLocal = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );
    final newUtc = tz.TZDateTime.from(newLocal, location).toUtc();

    // Проверяем сколько часов до тренировки
    final hoursUntil = schedule.scheduledAt
        .difference(DateTime.now().toUtc())
        .inMinutes / 60.0;

    String? cancellationReason;

    // Если < 24h — запрашиваем причину
    if (hoursUntil < 24) {
      cancellationReason = await _showReasonDialog();
      if (!mounted) return;
      if (cancellationReason == null) return;
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'reschedule_booking',
        params: {
          'p_booking_id': schedule.id,
          'p_new_scheduled_at': newUtc.toIso8601String(),
          'p_cancellation_reason': cancellationReason,
        },
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тренировка перенесена')),
        );
        context.read<ScheduleBloc>().add(SubscribeSchedules(trainerId));
      } else {
        final error = result['error'] ?? 'unknown';
        String errorMsg;
        switch (error) {
          case 'cancellation_reason_required':
            errorMsg = 'Укажите причину переноса — до тренировки менее 24 часов';
            break;
          case 'booking_not_found':
            errorMsg = 'Тренировка не найдена';
            break;
          case 'booking_not_scheduled':
            errorMsg = 'Тренировку нельзя перенести в текущем статусе';
            break;
          default:
            errorMsg = 'Ошибка переноса: $error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  /// Диалог для ввода причины переноса (обязателен при < 24h)
  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Причина переноса'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'До тренировки менее 24 часов — укажите причину переноса.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Например: заболел, форс-мажор...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx, reason);
            },
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  // ── Просмотр чека оплаты по тренировке ──

  /// Догружает пути к чекам одним пакетным запросом для тех оплаченных
  /// тренировок выбранного дня, которые ещё не в кэше.
  Future<void> _maybeLoadReceipts(List<Schedule> schedules) async {
    final paidIds = schedules
        .where((s) => s.isPaid && s.id != null)
        .map((s) => s.id!)
        .toSet();
    final missing = paidIds.difference(_loadedReceiptBookingIds);
    if (missing.isEmpty) return;

    final fetched = await GetIt.instance<PaymentRepository>()
        .getReceiptPathsForBookings(missing.toList());

    if (!mounted) return;
    setState(() {
      _receiptPaths.addAll(fetched);
      _loadedReceiptBookingIds.addAll(missing);
    });
  }

  Future<void> _showReceiptForBooking(String bookingId) async {
    final path = _receiptPaths[bookingId];
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: FutureBuilder<String?>(
          future: (path == null || path.isEmpty)
              ? Future.value(null)
              : GetIt.instance<PaymentRepository>().getReceiptSignedUrl(path),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }
            final url = snapshot.data;
            if (snapshot.hasError || url == null || url.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('Чек ещё не загружен',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ),
              );
            }
            return Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context, error, stack) => const SizedBox(
                      height: 200,
                      child: Center(child: Text('Ошибка загрузки изображения', style: TextStyle(color: Colors.white))),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───── Панель управления над календарём ─────

  Widget _buildCalendarControls(List<Schedule> allSchedules) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleCard(
            icon: Icons.calendar_view_week_outlined,
            label: 'Показать неделю',
            value: _calendarFormat == CalendarFormat.week,
            onChanged: (val) {
              setState(() {
                _calendarFormat =
                val ? CalendarFormat.week : CalendarFormat.month;
              });
            },
          ),
          if (_isCurrentWeekSelected) ...[
            const SizedBox(height: 8),
            _buildCopyWeekButton(allSchedules),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyWeekButton(List<Schedule> allSchedules) {
    final now = DateTime.now();
    final thisMonday = _startOfWeek(now);
    final thisSunday = thisMonday.add(const Duration(days: 6));
    final nextMonday = thisMonday.add(const Duration(days: 7));
    final nextSunday = nextMonday.add(const Duration(days: 6));

    final thisWeekCount = allSchedules.where((s) {
      final local = _normalizeDate(s.scheduledAt.toLocal());
      final status = s.status.toLowerCase();
      return !local.isBefore(thisMonday) &&
          !local.isAfter(thisSunday) &&
          status != 'canceled' &&
          status != 'rescheduled';
    }).length;

    final fmt = DateFormat('d MMM', 'ru_RU');
    final nextWeekLabel =
        '${fmt.format(nextMonday)} — ${fmt.format(nextSunday)}';

    final isDisabled = thisWeekCount == 0 || _isCopying;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDisabled
              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDisabled
              ? null
              : () async {
            await _copyCurrentWeekToNext(allSchedules);
          },
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _isCopying
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                )
                    : Icon(
                  Icons.content_copy_outlined,
                  size: 20,
                  color: isDisabled
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thisWeekCount == 0
                            ? 'Нет тренировок для копирования'
                            : 'Повторить эту неделю',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thisWeekCount == 0
                            ? 'Добавьте тренировки на эту неделю'
                            : '${_pluralizeSession(thisWeekCount)} → $nextWeekLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDisabled)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: value
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: value
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.outline,
                  fontWeight:
                  value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Theme.of(context).colorScheme.secondary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              thumbColor: WidgetStateProperty.all(Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      return const Center(child: Text('Нет данных пользователя'));
    }

    final double navBarHeight = 70.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: 'Расписание тренировок',
        trainerId: trainerId,
      ),
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<ScheduleBloc, ScheduleState>(
          listener: (context, state) {
            if (state is ScheduleSuccess) {
              _updateEvents(state.schedules);
            }
            if (state is ScheduleError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          buildWhen: (previous, current) {
            if (current is ScheduleSuccess) return true;
            if (current is ScheduleLoading && previous is ScheduleSuccess) return false;
            return true;
          },
          builder: (context, state) {
            final schedules =
            state is ScheduleSuccess ? state.schedules : null;

            if (schedules == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildCalendarControls(schedules),
                ),
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<Map<DateTime, List<Schedule>>>(
                valueListenable: _eventsNotifier,
                builder: (context, events, _) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: TableCalendar(
                      locale: 'ru_RU',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Месяц',
                        CalendarFormat.week: 'Неделя',
                      },
                      availableGestures:
                      AvailableGestures.horizontalSwipe,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      calendarStyle: const CalendarStyle(
                        markersMaxCount: 0,
                        outsideDaysVisible: false,
                        todayDecoration: BoxDecoration(),
                        selectedDecoration: BoxDecoration(),
                        defaultDecoration: BoxDecoration(),
                        weekendDecoration: BoxDecoration(),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle:
                        TextStyle(color: Colors.white),
                        weekendStyle:
                        TextStyle(color: Colors.white),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final now = DateTime.now();
                          final normalized = _normalizeDate(day);
                          final eventsCount = _eventsNotifier
                              .value[normalized]
                              ?.length ??
                              0;
                          final isFuture = !normalized
                              .isBefore(_normalizeDate(now));
                          return _buildDayCell(
                            day: day,
                            eventsCount: eventsCount,
                            textColor: isFuture
                                ? Theme.of(context)
                                .colorScheme
                                .surface
                                : Theme.of(context)
                                .colorScheme
                                .outline,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildDayCell(
                            day: day,
                            eventsCount: 0,
                            textColor: Theme.of(context)
                                .colorScheme
                                .surface,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary,
                              width: 1.5,
                            ),
                          );
                        },
                        selectedBuilder:
                            (context, day, focusedDay) {
                          return _buildDayCell(
                            day: day,
                            eventsCount: 0,
                            textColor: Theme.of(context)
                                .colorScheme
                                .surface,
                            bgColor: Theme.of(context)
                                .colorScheme
                                .secondary,
                          );
                        },
                        outsideBuilder:
                            (context, day, focusedDay) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  );
                },
                ),
                ),
                _buildScheduleSection(schedules),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: navBarHeight + bottomPadding + 20,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: isSelectedDayInPast
          ? null
          : Container(
        margin: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          heroTag: 'add_schedule_fab',
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddScheduleEntryScreen(
                    selectedDate: _selectedDay),
              ),
            );

            if (result == true && mounted) {
              context
                  .read<ScheduleBloc>()
                  .add(SubscribeSchedules(trainerId));
            }
          },
          backgroundColor:
          Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  bool get isSelectedDayInPast {
    final today = DateTime.now();
    final normalizedToday =
    DateTime(today.year, today.month, today.day);
    final normalizedSelected = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    return normalizedSelected.isBefore(normalizedToday);
  }

  Widget _buildScheduleSection(List<Schedule> all) {
    final filtered = all
        .where(
            (s) => isSameDay(s.scheduledAt.toLocal(), _selectedDay))
        .toList();

    final dateFormatter = DateFormat('dd.MM.yyyy');
    final dateString = dateFormatter.format(_selectedDay!);
    final count = filtered.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadReceipts(filtered);
    });

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            count == 0
                ? 'Тренировки на $dateString'
                : 'Тренировки на $dateString · ${_pluralizeSession(count)}',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Нет тренировок',
              style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._buildScheduleList(filtered),
      ]),
    );
  }

  List<Widget> _buildScheduleList(List<Schedule> list) {
    list.sort((a, b) => a.scheduledAt
        .toLocal()
        .compareTo(b.scheduledAt.toLocal()));

    return List<Widget>.generate(list.length, (index) {
      final schedule = list[index];
      final localDate = schedule.scheduledAt.toLocal();
      final timeStr =
          '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
      final isPast = localDate.isBefore(DateTime.now());
      final rs = _resolvedStatus(schedule, isPast: isPast);
      final isCanceled = rs == 'canceled';
      final isRescheduled = rs == 'rescheduled';
      final indicatorColor = isPast
          ? Theme.of(context).colorScheme.outline
          : Theme.of(context).colorScheme.secondary;

      if (rs == 'rescheduled') {
        debugPrint('WIDGET rescheduled: id=${schedule.id} rescheduledToAt=${schedule.rescheduledToAt}');
      }

      return Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 60, child: Text(timeStr)),
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (index != list.length - 1)
                  SizedBox(
                    height: 100,
                    child: DottedLine(
                      direction: Axis.vertical,
                      dashColor: indicatorColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Dismissible(
                key: Key(schedule.id ?? index.toString()),
                direction: (!isCanceled && !isRescheduled && !isPast)
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                confirmDismiss: (_) async {
                  await _confirmAction(schedule);
                  return false;
                },
                background: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_outlined,
                          color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'Действие',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundColorByStatus(rs,
                        forceGrey: false),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Клиент: ${clientById(schedule.clientId)}',
                        style: TextStyle(
                          color: textColorByStatus(rs),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _sessionTypeLabel(schedule),
                        style: TextStyle(
                          color:
                          textColorByStatus(rs).withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            iconByStatus(rs),
                            color: textColorByStatus(rs),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  textByStatus(rs),
                                  softWrap: true,
                                  style: TextStyle(
                                    color: textColorByStatus(rs),
                                    fontSize: 12,
                                  ),
                                ),
                                if (rs == 'rescheduled' &&
                                    schedule.rescheduledToAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '→ ${DateFormat('dd.MM.yyyy HH:mm').format(schedule.rescheduledToAt!.toLocal())}',
                                    style: TextStyle(
                                      color: textColorByStatus(rs)
                                          .withValues(alpha: 0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (rs == 'paid' && schedule.id != null)
                            InkWell(
                              onTap: () => _showReceiptForBooking(schedule.id!),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: textColorByStatus(rs),
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
