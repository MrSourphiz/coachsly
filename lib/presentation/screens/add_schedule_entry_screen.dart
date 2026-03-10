import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/entities/schedule_booking.dart';
import 'package:coachsly/presentation/blocs/client_bloc.dart';
import 'package:coachsly/presentation/blocs/schedule_bloc.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddScheduleEntryScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const AddScheduleEntryScreen({
    required this.selectedDate,
    Key? key,
  }) : super(key: key);

  @override
  State<AddScheduleEntryScreen> createState() => _AddScheduleEntryScreenState();
}

class _AddScheduleEntryScreenState extends State<AddScheduleEntryScreen> {
  String? selectedClientId;
  Client? selectedClient;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  int? scheduledWorkoutDayNumber;

  String description = '';
  String selectedMode = 'single'; // 'single' | 'program_day'
  bool needDescription = false;
  bool scheduleForAnotherDay = false;
  bool isTimeConflict = false;

  late final ClientBloc clientBloc;
  late final String trainerId;
  late final String trainerName;
  late final String tzName;

  late final ScheduleBloc scheduleBloc;
  List<Schedule> existingSchedules = [];

  @override
  void initState() {
    super.initState();
    final user = GetIt.instance<UserProvider>().user!;
    trainerId = user.id;
    tzName = user.timezone;
  //  trainerName = user.name ?? '';
    clientBloc = GetIt.instance<ClientBloc>();
    clientBloc.add(FetchClients(trainerId));

    scheduleBloc = GetIt.instance<ScheduleBloc>();
    scheduleBloc.add(FetchSchedules(trainerId));

    scheduleBloc.stream.listen((state) {
      if (state is ScheduleSuccess) {
        setState(() => existingSchedules = state.schedules);
      }
    });

    selectedDate = widget.selectedDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Запись клиента на ${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}' )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Клиент
            Text('Клиент', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            StreamBuilder<ClientState>(
              stream: clientBloc.stream,
              initialData: clientBloc.state,
              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state is ClientLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is ClientLoaded) {
                  final clients = state.clients;
                  if (clients.isEmpty) {
                    return Text('Нет клиентов', style: Theme.of(context).textTheme.labelMedium);
                  }
                  return DropdownButtonFormField<String>(
                    value: selectedClientId,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: clients
                        .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.first_name, style: Theme.of(context).textTheme.labelMedium),
                    ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedClientId = val;
                        selectedClient = clients.firstWhere((c) => c.id == val);
                        // Сброс режима, если у клиента нет программы
                        //if (selectedClient != null && !selectedClient!.hasActiveProgram) {
                        //  selectedMode = 'single';
                        //}
                      });
                    },
                  );
                } else if (state is ClientError) {
                  return Text(state.message, style: Theme.of(context).textTheme.labelMedium);
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 16),

            // Если клиент выбран — кнопка "Посмотреть / Назначить программу"
            if (selectedClient != null)

            const SizedBox(height: 16),

            // Chips выбора режима
            Text('Тип тренировки', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Разовая тренировка'),
                  selected: selectedMode == 'single',
                  onSelected: (_) => setState(() => selectedMode = 'single'),
                ),
                ChoiceChip(
                  label: const Text('Работа по тренировочному плану'),
                  selected: selectedMode == 'program_day',
                  onSelected: (_) => setState(() => selectedMode = 'program_day'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (selectedClient != null && selectedMode == 'program_day') ...[
                  Text(
                    selectedClient!.hasActiveProgram
                        ? 'Следующая тренировка:'
                        : 'Программа не назначена',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      if (selectedClient!.hasActiveProgram) {
                        _buildProgramInfo(context, selectedClient!);
                      } else {
                        // TODO: открыть экран назначения программы
                      }
                    },
                    child: Text(selectedClient!.hasActiveProgram ? 'Посмотреть' : 'Назначить'),
                  )
                ],
              ],
            ),

            const SizedBox(height: 16),

            TextButton(
              child: Text('Запись на другой день'),
              onPressed: () {
                scheduleForAnotherDay != true
                    ?  setState(() => scheduleForAnotherDay = true)
                    :  setState(() => scheduleForAnotherDay = false);
              },
            ),

            // Поля в зависимости от режима
            if (scheduleForAnotherDay == false) ...[
              const SizedBox(height: 16),
              _buildCupertinoTimePicker(context),//_buildTimePicker(context),
            ] else if (scheduleForAnotherDay == true) ...[
              const SizedBox(height: 16),
              _buildDatePicker(context),
              const SizedBox(height: 16),
              _buildCupertinoTimePicker(context),//_buildTimePicker(context),
            ],

            const SizedBox(height: 16),

            TextButton(
              child: Text('Добавить заметку'),
              onPressed: () {
                needDescription != true
                    ?  setState(() => needDescription = true)
                    :  setState(() => needDescription = false);
              },
            ),

            const SizedBox(height: 16),

            if (needDescription == true) ... [
              _buildScheduleNote(context),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),

      // Кнопка сохранения
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Сохранить'),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Дата', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final today = DateTime.now();
            final firstSelectable = DateTime(today.year, today.month, today.day);

            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate != null && selectedDate!.isAfter(firstSelectable)
                  ? selectedDate!
                  : firstSelectable,
              firstDate: firstSelectable,
              lastDate: DateTime(2100),
            );

            if (date != null) {
              setState(() => selectedDate = date);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              selectedDate != null
                  ? "${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}"
                  : 'Выбрать дату',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCupertinoTimePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Время', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            TimeOfDay? tempTime = selectedTime ?? TimeOfDay.now();

            await showDialog(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      content: SizedBox(
                        height: 270,
                        width: 300,
                        child: Column(
                          children: [
                            Expanded(
                              child: CupertinoTheme(
                                data: const CupertinoThemeData(
                                  brightness: Brightness.light,
                                ),
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.time,
                                  use24hFormat: true,
                                  initialDateTime: DateTime(
                                    2025,
                                    1,
                                    1,
                                    selectedTime?.hour ?? TimeOfDay.now().hour,
                                    selectedTime?.minute ?? TimeOfDay.now().minute,
                                  ),
                                  onDateTimeChanged: (DateTime dt) {
                                    tempTime = TimeOfDay(hour: dt.hour, minute: dt.minute);

                                    if (selectedDate != null) {
                                      final selectedDateTime = DateTime(
                                        selectedDate!.year,
                                        selectedDate!.month,
                                        selectedDate!.day,
                                        tempTime!.hour,
                                        tempTime!.minute,
                                      );

                                      final conflict = !_canBookSession(selectedDateTime);

                                      setDialogState(() {
                                        isTimeConflict = conflict;
                                      });

                                      // Обновляем поле в форме
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                children: [
                                  if (isTimeConflict)
                                    Text(
                                      'Выбранное время пересекается с другой тренировкой',
                                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Отмена'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextButton(
                                          onPressed: isTimeConflict
                                              ? null
                                              : () {
                                            setState(() {
                                              selectedTime = tempTime;
                                            });
                                            Navigator.pop(context);
                                          },
                                          child: const Text('ОК'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  selectedTime != null
                      ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
                      : 'Выбрать время',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (isTimeConflict)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Выбранное время пересекается с другой тренировкой',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgramInfo(BuildContext context, Client client) {
    final days = client.trainingDays?.join(' / ') ?? '';
    final weeks = client.durationWeeks ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Клиент будет записан согласно графику и продолжительности тренировочного плана.\n'
            'График: $days\n'
            'Продолжительность: $weeks недель',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildScheduleNote(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Заметка', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        TextField(
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Заметка о тренировке (необязательно)',
          ),
          onChanged: (val) => description = val,
        ),
      ],
    );
  }

  bool _canBookSession(
      DateTime newSessionTime, {
        Duration minInterval = const Duration(hours: 1),
      }) {
    for (final s in existingSchedules) {
      final existing = s.scheduledAt.toLocal();

      // Проверяем только тренировки в тот же день
      if (_isSameDay(existing, newSessionTime)) {
        final diff = existing.difference(newSessionTime).inMinutes.abs();
        if (diff < minInterval.inMinutes) {
          return false;
        }
      }
    }
    return true;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _notifyEdgeFunction(ScheduleBooking schedule) async {
    try {
      final payload = {
        'record': schedule.toJson()..update('description', (v) => v ?? '', ifAbsent: () => '')
      };
      print('JSON payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('https://vueumbnmjmxoppddblrr.supabase.co/functions/v1/new_booking_notify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('Telegram уведомление отправлено');
      } else {
        print('Ошибка отправки уведомления: ${response.body}');
      }
    } catch (e) {
      print('Ошибка при вызове Edge Function: $e');
    }
  }

  void _onSave() async {
    if (selectedClient == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите клиента и время')),
      );
      return;
    }

    if (scheduleForAnotherDay == true && selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату')),
      );
      return;
    }

    if (selectedMode == 'program_day' && selectedClient!.assignedProgramId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У клиента нет назначенной программы')),
      );
      return;
    }

    final localDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    tz.initializeTimeZones();
    final location = tz.getLocation(tzName);
    final local = tz.TZDateTime.from(localDateTime, location);
    final utc = local.toUtc();

    final schedule = Schedule(
      scheduledAt: utc,
      timezone: tzName,
      trainerId: trainerId,
      clientId: selectedClient!.id,
      sessionType: selectedMode,
      status: 'scheduled',
      workoutPlanId: selectedClient!.assignedProgramId,
      workoutDayNumber: scheduledWorkoutDayNumber,
      description: description,
    );

    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Вызываем UseCase напрямую, минуя Bloc, чтобы дождаться результата, получаем ИД записи в таблице
      final newId = await GetIt.instance<ScheduleBloc>().bookSession.execute(schedule);

      // Собираем новый объект Schedule с этим id
      final newSchedule = ScheduleBooking(
        id: newId,
        scheduledAt: schedule.scheduledAt,
        timezone: schedule.timezone,
        trainerId: schedule.trainerId,
        clientId: schedule.clientId,
        sessionType: schedule.sessionType,
        status: schedule.status,
        workoutPlanId: schedule.workoutPlanId,
        workoutDayNumber: schedule.workoutDayNumber,
        description: schedule.description,
      );

      // После успешного добавления вызываем Edge Function
      await _notifyEdgeFunction(newSchedule);

      Navigator.pop(context); // Закрываем индикатор загрузки
      Navigator.pop(context, true); // Закрываем экран с результатом

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись успешно добавлена')),
      );
    } catch (e) {
      Navigator.pop(context); // Закрываем индикатор загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка добавления записи: $e')),
      );
    }
  }

}
