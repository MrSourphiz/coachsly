import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/presentation/blocs/client_bloc.dart';
import 'package:coachsly/presentation/blocs/schedule_bloc.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/presentation/screens/add_schedule_entry_screen.dart';
import 'package:coachsly/ui/widgets/custom_app_bar.dart';

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({super.key});

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  late final String trainerId;
  late final ClientBloc clientBloc;
  List<Client> clientsList = [];
  final DateTime _currentDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    final user = GetIt.instance<UserProvider>().user!;
    trainerId = user.id;
    clientBloc = GetIt.instance<ClientBloc>();
    clientBloc.add(FetchClients(trainerId));

    clientBloc.stream.listen((state) {
      if (state is ClientLoaded) {
        setState(() => clientsList = state.clients);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>().user;
    if (user != null) {
      context.read<ScheduleBloc>().add(FetchSchedules(user.id));
    }
  }

  Color backgroundColorByStatus(String status, {required bool forceGrey}) {
    if (forceGrey) return const Color(0xFF374151);
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF256D47);
      case 'canceled':
        return const Color(0xFF801A1A);
      case 'scheduled':
        return const Color(0xFF997A00);
      case 'completed':
        return const Color(0xFF374151);
      default:
        return const Color(0xFF997A00);
    }
  }

  IconData iconByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'canceled':
        return Icons.cancel;
      case 'completed':
        return Icons.fitness_center;
      case 'scheduled':
        return Icons.message;
      default:
        return Icons.question_mark;
    }
  }

  String textByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return 'Уведомление отправлено клиенту';
      case 'confirmed':
        return 'Клиент подтвердил тренировку';
      case 'canceled':
        return 'Тренировка отменена';
      case 'completed':
        return 'Тренировка выполнена';
      default:
        return 'Неизвестно';
    }
  }

  String textBySessionType(String sessionType) {
    switch (sessionType.toLowerCase()) {
      case 'single':
        return 'Разовая тренировка';
      case 'program_day':
        return 'Работа по тренировочному плану';
      default:
        return 'Консультация';
    }
  }

  String clientById(String clientId) {
    final index = clientsList.indexWhere((c) => c.id == clientId);
    if (index == -1) return 'Неизвестно';
    return clientsList[index].first_name;
  }

  Color textColorByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFFD2FFE0);
      case 'canceled':
        return const Color(0xFFFFCCCC);
      case 'scheduled':
        return Colors.white;
      case 'completed':
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  // Метод для подсчета статистики по тренировкам
  Map<String, int> _calculateStatistics(List<Schedule> schedules) {
    final todaySchedules = schedules.where((s) {
      final scheduleDate = s.scheduledAt.toLocal();
      return scheduleDate.year == _currentDay.year &&
          scheduleDate.month == _currentDay.month &&
          scheduleDate.day == _currentDay.day;
    }).toList();

    final totalCount = todaySchedules.length;
    final unconfirmedCount = todaySchedules
        .where((s) => s.status.toLowerCase() == 'scheduled')
        .length;
    final hasProblems = unconfirmedCount > 0;

    return {
      'total': totalCount,
      'unconfirmed': unconfirmedCount,
      'hasProblems': hasProblems ? 1 : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      return const Center(child: Text('Нет данных пользователя'));
    }

    final trainerId = user.id;
    final double navBarHeight = 70.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: 'Тренировки сегодня',
        trainerId: trainerId,
      ),
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ScheduleBloc, ScheduleState>(
          builder: (context, state) {
            if (state is ScheduleLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ScheduleSuccess) {
              final statistics = _calculateStatistics(state.schedules);
              final todaySchedules = state.schedules.where((s) {
                final scheduleDate = s.scheduledAt.toLocal();
                return scheduleDate.year == _currentDay.year &&
                    scheduleDate.month == _currentDay.month &&
                    scheduleDate.day == _currentDay.day;
              }).toList();

              // Извлекаем значения статистики с проверкой на null
              final total = statistics['total'] ?? 0;
              final unconfirmed = statistics['unconfirmed'] ?? 0;
              final hasProblems = statistics['hasProblems'] == 1;

              return Column(
                children: [
                  // Статистика дня
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Сегодня под контролем',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          total == 0
                              ? 'Нет тренировок на сегодня'
                              : '$total тренировок · ${hasProblems ? '$unconfirmed не подтверждены' : 'без проблем'}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: (total - unconfirmed) / total,
                            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                            color: hasProblems
                                ? Colors.amber
                                : Colors.green,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Таймлайн тренировок
                  Expanded(
                    child: todaySchedules.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет тренировок на сегодня',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: todaySchedules.length,
                      itemBuilder: (context, index) {
                        return _buildScheduleItem(
                          todaySchedules[index],
                          index,
                          todaySchedules.length,
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            return const Center(child: Text('Нет данных'));
          },
        ),
      ),
      /*
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          heroTag: 'add_schedule_fab_today',
          onPressed: () async {
            final result = await PersistentNavBarNavigator.pushNewScreen(
              context,
              screen: AddScheduleEntryScreen(selectedDate: _currentDay),
              withNavBar: false,
              pageTransitionAnimation: PageTransitionAnimation.cupertino,
            );

            if (result == true) {
              context.read<ScheduleBloc>().add(FetchSchedules(trainerId));
            }
          },
          child: const Icon(Icons.add),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
       */
    );
  }

  Widget _buildScheduleItem(Schedule schedule, int index, int totalCount) {
    final localDate = schedule.scheduledAt.toLocal();
    final timeStr =
        '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    final isPast = localDate.isBefore(DateTime.now());
    final indicatorColor = isPast
        ? Theme.of(context).colorScheme.outline
        : Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColorByStatus(
                  schedule.status,
                  forceGrey: isPast,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Клиент: ${clientById(schedule.clientId)}',
                    style: TextStyle(
                      color: textColorByStatus(schedule.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    textBySessionType(schedule.sessionType),
                    style: TextStyle(
                      color: textColorByStatus(schedule.status),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        iconByStatus(schedule.status),
                        color: textColorByStatus(schedule.status),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          textByStatus(schedule.status),
                          style: TextStyle(
                            color: textColorByStatus(schedule.status),
                            fontSize: 12,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}