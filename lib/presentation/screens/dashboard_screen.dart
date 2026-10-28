import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/ui/widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';

// ───── Модель отчёта ─────
class WeeklyReport {
  final double totalRevenue;
  final int sentNotifications;
  final int completedSessions;
  final List<Map<String, dynamic>> expiredSubscriptions;
  final List<Map<String, dynamic>> exhaustedBlocks;
  final String? topClientId;
  final int topClientSessionCount;
  final int confirmedSessions;
  final int totalPlannedSessions;

  const WeeklyReport({
    required this.totalRevenue,
    required this.sentNotifications,
    required this.completedSessions,
    required this.expiredSubscriptions,
    required this.exhaustedBlocks,
    this.topClientId,
    required this.topClientSessionCount,
    required this.confirmedSessions,
    required this.totalPlannedSessions,
  });
}

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({super.key});

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  late final String trainerId;
  late final ClientBloc clientBloc;
  List<Client> clientsList = [];
  bool _demoSheetShown = false;
  final DateTime _currentDay = DateTime.now();

  String _statusFilter = 'all';

  double? _singlePrice;
  double? _blockPrice;
  double? _subscriptionPrice;

  WeeklyReport? _weeklyReport;
  bool _reportLoading = false;
  bool _reportExpanded = false;

  // ── Кэш путей к чекам: booking_id -> receipt_photo_url (или null, если чека нет) ──
  final Map<String, String?> _receiptPaths = {};
  final Set<String> _loadedReceiptBookingIds = {};

  bool get _shouldShowReport => _currentDay.weekday == DateTime.monday;

  @override
  void initState() {
    super.initState();
    final user = GetIt.instance<UserProvider>().user!;
    trainerId = user.id;

    // ── Клиенты ──
    // Читаем текущее состояние напрямую — clientBloc singleton,
    // BlocBuilder в build() уже отреагирует на новые события.
    // Ручной stream.listen + setState не нужен — это двойная перерисовка.
    clientBloc = GetIt.instance<ClientBloc>();

    if (clientBloc.state is ClientLoaded) {
      clientsList = (clientBloc.state as ClientLoaded).clients;
    }

    if (clientsList.isEmpty) {
      clientBloc.add(SubscribeClients(trainerId));
    }

    // ── Расписание ──
    // ScheduleBloc — singleton, подписка уже активна с момента запуска приложения.
    // Дополнительный SubscribeSchedules здесь не нужен — данные придут через BlocBuilder.

    // Загружаем цены только если ещё не загружены (кэшируем в полях виджета)
    if (_singlePrice == null && _blockPrice == null && _subscriptionPrice == null) {
      _loadPrices();
    }

    if (_shouldShowReport && _weeklyReport == null) {
      _loadWeeklyReport();
    }

    // Показываем bottom sheet с демо-клиентами при первом входе
    _maybeShowDemoSheet();
  }

  Future<void> _maybeShowDemoSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('demo_sheet_shown_$trainerId') ?? false;
    if (shown) return;

    // Ждём первый фрейм чтобы context был готов
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Показываем только если клиентов ещё нет (демо ещё не подгрузились)
      // или если они уже есть и среди них демо
      final state = clientBloc.state;
      final hasRealClients = state is ClientLoaded &&
          state.clients.isNotEmpty &&
          !state.clients.any((c) => c.isDemo);
      if (hasRealClients) return; // у тренера уже есть реальные клиенты

      _showDemoSheet();
    });
  }

  void _showDemoSheet() {
    if (_demoSheetShown) return;
    _demoSheetShown = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DemoWelcomeSheet(
        onDemoLoaded: () {
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        },
        clientBloc: clientBloc,
      ),
    ).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('demo_sheet_shown_$trainerId', true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ───── Загрузка цен ─────

  Future<void> _loadPrices() async {
    try {
      final details = await GetIt.instance<SupabaseDataSource>()
          .getTrainerPaymentDetails(trainerId);
      if (details != null && mounted) {
        setState(() {
          _singlePrice = (details['single_price'] as num?)?.toDouble();
          _blockPrice = (details['block_price'] as num?)?.toDouble();
          _subscriptionPrice =
              (details['subscription_price'] as num?)?.toDouble();
        });
      }
    } catch (e) {
      // Цены не критичны
    }
  }

  // ───── Загрузка отчёта ─────

  DateTime _startOfWeek(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: diff));
  }

  Future<void> _loadWeeklyReport() async {
    setState(() => _reportLoading = true);

    try {
      final lastMonday =
      _startOfWeek(_currentDay).subtract(const Duration(days: 7));
      final lastSunday = lastMonday.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      final ds = GetIt.instance<SupabaseDataSource>();

      final results = await Future.wait([
        ds.getWeeklyPayments(
            trainerId: trainerId, from: lastMonday, to: lastSunday),
        ds.getSentNotificationsCount(
            trainerId: trainerId, from: lastMonday, to: lastSunday),
        ds.getExpiredSubscriptions(
            trainerId: trainerId, from: lastMonday, to: lastSunday),
        ds.getExhaustedBlocks(
            trainerId: trainerId, from: lastMonday, to: lastSunday),
      ]);

      final payments = results[0] as List<Map<String, dynamic>>;
      final notifCount = results[1] as int;
      final expiredSubs = results[2] as List<Map<String, dynamic>>;
      final exhaustedBlocks = results[3] as List<Map<String, dynamic>>;

      final totalRevenue = payments.fold<double>(
        0,
            (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );

      if (mounted) {
        setState(() {
          _weeklyReport = WeeklyReport(
            totalRevenue: totalRevenue,
            sentNotifications: notifCount,
            completedSessions: 0,
            expiredSubscriptions: expiredSubs,
            exhaustedBlocks: exhaustedBlocks,
            topClientSessionCount: 0,
            confirmedSessions: 0,
            totalPlannedSessions: 0,
          );
        });
      }
    } catch (e) {
      debugPrint('_loadWeeklyReport error: $e');
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  WeeklyReport _enrichReport(
      WeeklyReport base, List<Schedule> allSchedules) {
    final lastMonday =
    _startOfWeek(_currentDay).subtract(const Duration(days: 7));
    final lastSunday = lastMonday.add(const Duration(days: 6));

    final lastWeek = allSchedules.where((s) {
      final local = s.scheduledAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      return !d.isBefore(lastMonday) && !d.isAfter(lastSunday);
    }).toList();

    final completed = lastWeek
        .where((s) =>
    s.status.toLowerCase() == 'completed' ||
        s.status.toLowerCase() == 'confirmed')
        .length;

    final confirmed = lastWeek
        .where((s) => s.status.toLowerCase() == 'confirmed')
        .length;

    final total = lastWeek
        .where((s) =>
    s.status.toLowerCase() != 'canceled' &&
        s.status.toLowerCase() != 'rescheduled')
        .length;

    final Map<String, int> clientCount = {};
    for (final s in lastWeek) {
      final status = s.status.toLowerCase();
      if (status == 'canceled' || status == 'rescheduled') continue;
      clientCount[s.clientId] = (clientCount[s.clientId] ?? 0) + 1;
    }
    String? topClientId;
    int topCount = 0;
    clientCount.forEach((id, count) {
      if (count > topCount) {
        topCount = count;
        topClientId = id;
      }
    });

    return WeeklyReport(
      totalRevenue: base.totalRevenue,
      sentNotifications: base.sentNotifications,
      completedSessions: completed,
      expiredSubscriptions: base.expiredSubscriptions,
      exhaustedBlocks: base.exhaustedBlocks,
      topClientId: topClientId,
      topClientSessionCount: topCount,
      confirmedSessions: confirmed,
      totalPlannedSessions: total,
    );
  }

  // ───── Вспомогательные методы ─────

  /// Ожидаемая выручка за день — только по разовым тренировкам (session_type
  /// == 'single'). Блок/абонемент оплачивается один раз вперёд при покупке,
  /// а не за каждое посещение, поэтому считать их полную стоимость на день
  /// визита было бы некорректно — искусственно раздувает цифру, если у
  /// клиента в этот день просто плановое занятие по уже оплаченному блоку.
  double _calculateExpectedRevenue(List<Schedule> schedules) {
    double total = 0;
    for (final s in schedules) {
      final status = s.status.toLowerCase();
      if (status == 'canceled' || status == 'rescheduled') continue;
      if (s.sessionType.toLowerCase() == 'single') {
        total += _singlePrice ?? 0;
      }
    }
    return total;
  }

  String _pluralizeSession(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) return '$count занятий';
    if (mod10 == 1) return '$count занятие';
    if (mod10 >= 2 && mod10 <= 4) return '$count занятия';
    return '$count занятий';
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('d MMMM, EEEE', 'ru_RU');
    return formatter.format(date);
  }

  String clientById(String clientId) {
    final index = clientsList.indexWhere((c) => c.id == clientId);
    if (index == -1) return 'Неизвестно';
    return clientsList[index].firstName;
  }

  // ───── Статусы ─────

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

  // ───── Виджет отчёта ─────

  Widget _buildWeeklyReportBanner(WeeklyReport report) {
    final savedMinutes = report.sentNotifications * 2;
    final attendanceRate = report.totalPlannedSessions > 0
        ? (report.confirmedSessions / report.totalPlannedSessions * 100)
        .round()
        : 0;

    final hasGrowthPoints = report.expiredSubscriptions.isNotEmpty ||
        report.exhaustedBlocks.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _reportExpanded = !_reportExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '📊',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Итоги прошлой недели',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color:
                            Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report.totalRevenue > 0
                              ? '${report.totalRevenue.toStringAsFixed(0)} ₽ · ${_pluralizeSession(report.completedSessions)}'
                              : _pluralizeSession(
                              report.completedSessions),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _reportExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildReportContent(
                report, savedMinutes, attendanceRate, hasGrowthPoints),
            crossFadeState: _reportExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(WeeklyReport report, int savedMinutes,
      int attendanceRate, bool hasGrowthPoints) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
              color: Theme.of(context)
                  .colorScheme
                  .surface
                  .withValues(alpha: 0.2)),
          const SizedBox(height: 12),

          if (report.totalRevenue > 0) ...[
            _buildReportBlock(
              emoji: '💰',
              title: 'Доход под контролем',
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                        text:
                        'За эту неделю с помощью приложения вы заработали: '),
                    TextSpan(
                      text:
                      '${report.totalRevenue.toStringAsFixed(0)} ₽',
                      style:
                      const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (report.sentNotifications > 0) ...[
            _buildReportBlock(
              emoji: '🤖',
              title: 'Автопилот сработал',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Мы отправили за вас ${report.sentNotifications} напоминаний клиентам.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('⏱️',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'В среднем 2 мин. на сообщение — мы сэкономили вам $savedMinutes минут жизни',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (report.totalPlannedSessions > 0) ...[
            _buildReportBlock(
              emoji: '📈',
              title: 'Посещаемость',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${report.confirmedSessions} из ${report.totalPlannedSessions} клиентов подтвердили тренировки ($attendanceRate%)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: report.totalPlannedSessions > 0
                          ? report.confirmedSessions /
                          report.totalPlannedSessions
                          : 0,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        attendanceRate >= 80
                            ? const Color(0xFF4ADE80)
                            : attendanceRate >= 50
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFF87171),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (report.topClientId != null &&
              report.topClientSessionCount > 1) ...[
            _buildReportBlock(
              emoji: '🏆',
              title: 'Самый активный клиент',
              child: Text(
                '${clientById(report.topClientId!)} — ${_pluralizeSession(report.topClientSessionCount)} за неделю. Отличный результат!',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (hasGrowthPoints)
            _buildReportBlock(
              emoji: '⚠️',
              title: 'Точки роста',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...report.expiredSubscriptions.map((sub) {
                    final clientName = clientById(
                        sub['client_id'] as String? ?? '');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'У клиента $clientName истёк абонемент. Formeo позаботился о своевременном напоминании.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    );
                  }),
                  ...report.exhaustedBlocks.map((block) {
                    final clientName = clientById(
                        block['client_id'] as String? ?? '');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'У клиента $clientName закончился блок тренировок. Клиент получил уведомление.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportBlock({
    required String emoji,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  // ───── Build ─────

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      return const Center(child: Text('Нет данных пользователя'));
    }

    return BlocListener<ClientBloc, ClientState>(
        bloc: clientBloc,
        listener: (context, state) {
          if (state is ClientLoaded) {
            setState(() => clientsList = state.clients);
          }
        },
        child: Scaffold(
          extendBody: true,
          appBar: CustomAppBar(
            title: _formatDate(_currentDay),
            trainerId: trainerId,
          ),
          body: SafeArea(
            bottom: false,
            child: BlocBuilder<ScheduleBloc, ScheduleState>(
              // ✅ buildWhen: не перестраиваем виджет при ScheduleLoading если
              // уже есть данные — это предотвращает мигание спиннера при обновлении
              buildWhen: (previous, current) {
                if (current is ScheduleLoading && previous is ScheduleSuccess) return false;
                return true;
              },
              builder: (context, state) {
                // ✅ Читаем текущее состояние напрямую из bloc, а не только из BlocBuilder.
                // Если bloc уже в ScheduleSuccess когда виджет строится — используем сразу,
                // не ждём следующего emit (который может не прийти)
                final blocState = context.read<ScheduleBloc>().state;
                final resolvedState = (blocState is ScheduleSuccess) ? blocState : state;

                final schedules = resolvedState is ScheduleSuccess
                    ? resolvedState.schedules
                    : null;

                if (schedules == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todaySchedules = schedules.where((s) {
                  final d = s.scheduledAt.toLocal();
                  return d.year == _currentDay.year &&
                      d.month == _currentDay.month &&
                      d.day == _currentDay.day;
                }).toList()
                  ..sort(
                          (a, b) => a.scheduledAt.compareTo(b.scheduledAt));

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _maybeLoadReceipts(todaySchedules);
                });

                final total = todaySchedules.length;

                final needsAttention = todaySchedules
                    .where((s) =>
                s.status.toLowerCase() == 'scheduled' ||
                    s.status.toLowerCase() == 'no_response')
                    .length;

                final noResponseCount = todaySchedules
                    .where(
                        (s) => s.status.toLowerCase() == 'no_response')
                    .length;

                final canceled = todaySchedules
                    .where((s) => s.status.toLowerCase() == 'canceled')
                    .length;

                final rescheduled = todaySchedules
                    .where(
                        (s) => s.status.toLowerCase() == 'rescheduled')
                    .length;

                final expectedRevenue =
                _calculateExpectedRevenue(todaySchedules);
                // Метрика теперь считает только разовые тренировки —
                // цену показываем, только если у тренера вообще задана
                // цена разового занятия.
                final hasPrices = _singlePrice != null;

                final filtered = _statusFilter == 'all'
                    ? todaySchedules
                    : todaySchedules
                    .where((s) =>
                s.status.toLowerCase() == _statusFilter)
                    .toList();

                final enrichedReport = _weeklyReport != null
                    ? _enrichReport(_weeklyReport!, schedules)
                    : null;

                return Column(
                  children: [
                    // ───── Баннер отчёта ─────
                    if (_shouldShowReport) ...[
                      if (_reportLoading)
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Готовим итоги недели...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (enrichedReport != null)
                        _buildWeeklyReportBanner(enrichedReport),
                    ],

                    // ───── Шапка ─────
                    if (total > 0)
                      Container(
                        padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                _buildStatusSummary(
                                  total: total,
                                  needsAttention: needsAttention,
                                  noResponseCount: noResponseCount,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (hasPrices && expectedRevenue > 0) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.payments_outlined,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Ожидаемая выручка по разовым: ${expectedRevenue.toStringAsFixed(0)} ₽',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _filterChip('Все', 'all', total),
                                if (needsAttention - noResponseCount > 0)
                                  _filterChip(
                                    'Не подтверждены',
                                    'scheduled',
                                    needsAttention - noResponseCount,
                                  ),
                                if (noResponseCount > 0)
                                  _filterChip(
                                    'Нет ответа',
                                    'no_response',
                                    noResponseCount,
                                  ),
                                if (canceled > 0)
                                  _filterChip(
                                    'Отменены',
                                    'canceled',
                                    canceled,
                                  ),
                                if (rescheduled > 0)
                                  _filterChip(
                                    'Перенесены',
                                    'rescheduled',
                                    rescheduled,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // ───── Список ─────
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              total == 0
                                  ? 'Нет занятий на сегодня.\nДобавить занятия можно на экране Расписания →'
                                  : 'Нет занятий по выбранному фильтру',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline,
                              ),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildScheduleItem(
                            filtered[index],
                            index,
                            filtered.length,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        )); // Scaffold + BlocListener
  }

  String _buildStatusSummary({
    required int total,
    required int needsAttention,
    required int noResponseCount,
  }) {
    if (needsAttention == 0) {
      return '${_pluralizeSession(total)} · без проблем';
    }
    if (noResponseCount > 0 && needsAttention == noResponseCount) {
      return '${_pluralizeSession(total)} · $noResponseCount не ответили';
    }
    if (noResponseCount > 0) {
      final unconfirmed = needsAttention - noResponseCount;
      return '${_pluralizeSession(total)} · $unconfirmed не подтверждены, $noResponseCount не ответили';
    }
    return '${_pluralizeSession(total)} · $needsAttention не подтверждены';
  }

  Widget _filterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
            isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  // ───── Карточка тренировки ─────

  String _resolvedStatus(Schedule s, {required bool isPast}) {
    if (isPast) return 'past';

    final bookingState = s.bookingState.toLowerCase();
    final confirmationState = s.confirmationState.toLowerCase();

    if (bookingState == 'canceled') return 'canceled';
    if (bookingState == 'rescheduled') return 'rescheduled';
    if (bookingState == 'completed') return 'completed';

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

    final now = DateTime.now().toUtc();
    final hoursLeft = s.scheduledAt.difference(now).inMinutes / 60.0;

    if (confirmationState == 'no_response') {
      return hoursLeft <= 8 ? 'urgent' : 'no_response';
    }

    if (hoursLeft <= 8) return 'urgent';
    if (hoursLeft <= 24) return 'awaiting24';

    return 'scheduled';
  }

  bool _canLogWorkout(Schedule s, String rs) {
    return (rs == 'confirmed' || rs == 'paid') &&
        s.quickPlanId != null &&
        s.quickPlanDayOfWeek != null;
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
    DateTime pickedDate =
    DateTime(originalLocal.year, originalLocal.month, originalLocal.day);
    TimeOfDay pickedTime =
    TimeOfDay(hour: originalLocal.hour, minute: originalLocal.minute);

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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(dateStr),
                  onTap: () async {
                    final today = DateTime.now();
                    final first =
                    DateTime(today.year, today.month, today.day);
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate:
                      pickedDate.isBefore(first) ? first : pickedDate,
                      firstDate: first,
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setS(() => pickedDate = d);
                  },
                ),
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
        .inMinutes /
        60.0;

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
      } else {
        final error = result['error'] ?? 'unknown';
        String errorMsg;
        switch (error) {
          case 'cancellation_reason_required':
            errorMsg =
            'Укажите причину переноса — до тренировки менее 24 часов';
            break;
          case 'booking_not_found':
            errorMsg = 'Тренировка не найдена';
            break;
          case 'booking_not_scheduled':
            errorMsg =
            'Тренировку нельзя перенести в текущем статусе';
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
  /// тренировок, которые ещё не в кэше. Вызывается после каждой отрисовки
  /// списка — но реально бьёт в БД только когда появляются новые booking_id.
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

  Widget _buildScheduleItem(Schedule schedule, int index, int totalCount) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              timeStr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
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
              if (index != totalCount - 1)
                SizedBox(
                  height: 116,
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.white, size: 28),
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
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColorByStatus(rs, forceGrey: false),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Клиент: ${clientById(schedule.clientId)}',
                      style: TextStyle(
                        color: textColorByStatus(rs),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sessionTypeLabel(schedule),
                      style: TextStyle(
                        color: textColorByStatus(rs).withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                style: TextStyle(
                                  color: textColorByStatus(rs),
                                  fontSize: 12,
                                ),
                                softWrap: true,
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
                      ],
                    ),
                    // ── Кнопка "Посмотреть чек" — стилистически идентична
                    // кнопке "Открыть тренировку" ниже: полноширинный
                    // OutlinedButton.icon вместо иконки внутри строки статуса ──
                    if (rs == 'paid' && schedule.id != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showReceiptForBooking(schedule.id!),
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Посмотреть чек'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColorByStatus(rs),
                            side: BorderSide(color: textColorByStatus(rs).withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                    if (_canLogWorkout(schedule, rs)) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.pushNamed('workoutLog', extra: schedule),
                          icon: const Icon(Icons.fitness_center, size: 16),
                          label: const Text('Открыть тренировку'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColorByStatus(rs),
                            side: BorderSide(color: textColorByStatus(rs).withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Виджет: bottom sheet с приветствием демо-клиентов
// ─────────────────────────────────────────────────────────────────────────────

class _DemoWelcomeSheet extends StatefulWidget {
  final VoidCallback onDemoLoaded;
  final ClientBloc clientBloc;

  const _DemoWelcomeSheet({
    required this.onDemoLoaded,
    required this.clientBloc,
  });

  @override
  State<_DemoWelcomeSheet> createState() => _DemoWelcomeSheetState();
}

class _DemoWelcomeSheetState extends State<_DemoWelcomeSheet> {
  late final Stream<ClientState> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.clientBloc.stream;

    // Проверяем текущее состояние — демо уже могут быть загружены
    final current = widget.clientBloc.state;
    if (current is ClientLoaded && current.clients.isNotEmpty) {
      // Демо уже есть — сразу показываем кнопку, не закрываем автоматически
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClientState>(
      stream: _stream,
      initialData: widget.clientBloc.state,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final demoLoaded = state is ClientLoaded && state.clients.isNotEmpty;


        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24, 20, 24,
            70 + MediaQuery.of(context).padding.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ручка
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Иконка
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '🎯',
                    style: TextStyle(fontSize: 32),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Добро пожаловать в Formeo!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.surface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Мы создали 3 демо-клиента, чтобы вы могли сразу оценить весь функционал приложения.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Что показываем
                _featureRow(context, '📅', 'Расписание тренировок на сегодня'),
                const SizedBox(height: 10),
                _featureRow(context, '👥', 'Карточки клиентов с историей и оплатами'),
                const SizedBox(height: 10),
                _featureRow(context, '📊', 'Дневник питания и опросы самочувствия'),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onDemoLoaded,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      demoLoaded ? 'Начать изучение' : 'Понятно',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ), // SingleChildScrollView
        );
      },
    );
  }

  Widget _featureRow(BuildContext context, String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}