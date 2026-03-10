import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart'; // Добавляем для форматирования даты

import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/presentation/blocs/client_bloc.dart';
import 'package:coachsly/presentation/blocs/schedule_bloc.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/presentation/screens/add_schedule_entry_screen.dart';
import 'package:coachsly/ui/widgets/custom_app_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final String trainerId;
  late final ClientBloc clientBloc;
  List<Client> clientsList = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ValueNotifier<Map<DateTime, List<Schedule>>> _eventsNotifier = ValueNotifier({});

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Schedule> _getEventsForDay(DateTime day) {
    final map = _eventsNotifier.value;
    return map[_normalizeDate(day)] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
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

  Widget _buildKettlebellIndicator(int count) {
    if (count == 0) return const SizedBox.shrink();

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
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.secondary, BlendMode.srcIn),
            ),
          ),
        if (showPlus)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '+',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildCalendarDayMarker(DateTime date, int eventsCount, bool isTodayOrFuture) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${date.day}',
          style: TextStyle(
            color: isTodayOrFuture
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        _buildKettlebellIndicator(eventsCount),
      ],
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
          },
          buildWhen: (previous, current) =>
          current is ScheduleLoading || current is ScheduleSuccess,
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<Map<DateTime, List<Schedule>>>(
                    valueListenable: _eventsNotifier,
                    builder: (context, events, _) {
                      return Container(
                        margin: const EdgeInsets.all(8.0),
                        child: TableCalendar(
                          locale: 'ru_RU',
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const {
                            CalendarFormat.month: '',
                          },
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          eventLoader: _getEventsForDay,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarStyle: CalendarStyle(
                            markerDecoration: const BoxDecoration(),
                            markersMaxCount: 0,
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: Colors.white),
                            weekendStyle: TextStyle(color: Colors.white),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              final now = DateTime.now();
                              final normalized = _normalizeDate(day);
                              final eventsCount = _eventsNotifier.value[normalized]?.length ?? 0;
                              final isTodayOrFuture =
                              !normalized.isBefore(_normalizeDate(now));

                              return buildCalendarDayMarker(day, eventsCount, isTodayOrFuture);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (state is ScheduleLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state is ScheduleSuccess)
                  _buildScheduleSection(state.schedules) // Изменяем вызов метода
                else
                  const SliverFillRemaining(
                    child: Center(child: Text('Нет данных')),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(height: navBarHeight + bottomPadding + 20),
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
            final result = await PersistentNavBarNavigator.pushNewScreen(
              context,
              screen: AddScheduleEntryScreen(selectedDate: _selectedDay),
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
    );
  }

  bool get isSelectedDayInPast {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedSelected = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    return normalizedSelected.isBefore(normalizedToday);
  }

  // Новый метод для построения всей секции с заголовком и списком
  Widget _buildScheduleSection(List<Schedule> all) {
    final filtered =
    all.where((s) => isSameDay(s.scheduledAt.toLocal(), _selectedDay));

    // Форматируем дату для заголовка
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final dateString = dateFormatter.format(_selectedDay!);

    return SliverList(
      delegate: SliverChildListDelegate([
        // Заголовок с датой
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            'Тренировки на $dateString',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        // Список тренировок или сообщение об отсутствии
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Нет тренировок',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._buildScheduleList(filtered.toList()),
      ]),
    );
  }

  // Обновленный метод для построения списка тренировок
  List<Widget> _buildScheduleList(List<Schedule> list) {
    list.sort((a, b) => a.scheduledAt.toLocal().compareTo(b.scheduledAt.toLocal()));

    return List<Widget>.generate(list.length, (index) {
      final schedule = list[index];
      final localDate = schedule.scheduledAt.toLocal();
      final timeStr =
          '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
      final isPast = localDate.isBefore(DateTime.now());
      final indicatorColor = isPast
          ? Theme.of(context).colorScheme.outline
          : Theme.of(context).colorScheme.secondary;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                    Text('Клиент: ${clientById(schedule.clientId)}'),
                    Text(textBySessionType(schedule.sessionType)),
                    Row(
                      children: [
                        Icon(
                          iconByStatus(schedule.status),
                          color: textColorByStatus(schedule.status),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          softWrap: true,
                          textByStatus(schedule.status),
                          style: TextStyle(
                            color: textColorByStatus(schedule.status),
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
    });
  }
}