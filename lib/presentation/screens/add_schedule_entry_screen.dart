import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/domain/entities/assigned_quick_plan.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'dart:async';

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

  String description = '';
  bool needDescription = false;
  bool scheduleForAnotherDay = false;
  bool isTimeConflict = false;
  bool _isSaving = false;

  // ── Активная быстрая программа выбранного клиента (для привязки брони
  // к конкретному дню программы) ──
  ActiveQuickPlanInfo? _activePlanInfo;
  int? _selectedQuickPlanDay;
  bool _loadingActivePlan = false;

  late final ClientBloc _clientBloc;
  late final ScheduleBloc _scheduleBloc;
  late final ClientRepository _clientRepository;
  late final String _trainerId;
  late final String _tzName;

  List<Schedule> _existingSchedules = [];

  // clientId-шники у которых есть активный блок/абонемент (для фильтрации)
  Set<String> _clientsWithActiveProduct = {};
  bool _productsLoading = false;

  StreamSubscription<ScheduleState>? _scheduleSubscription;
  StreamSubscription<ClientState>? _clientsSubscription;

  @override
  void initState() {
    super.initState();
    final user = GetIt.instance<UserProvider>().user!;
    _trainerId = user.id;
    _tzName = user.timezone;

    _clientBloc = GetIt.instance<ClientBloc>();
    _scheduleBloc = GetIt.instance<ScheduleBloc>();
    _clientRepository = GetIt.instance<ClientRepository>();

    final currentScheduleState = _scheduleBloc.state;
    if (currentScheduleState is ScheduleSuccess) {
      _existingSchedules = currentScheduleState.schedules;
    }

    _scheduleSubscription = _scheduleBloc.stream.listen((state) {
      if (state is ScheduleSuccess && mounted) {
        setState(() => _existingSchedules = state.schedules);
      }
    });

    // При первичной загрузке и при каждом обновлении списка клиентов
    // пересчитываем множество клиентов с активными продуктами
    final currentClientState = _clientBloc.state;
    if (currentClientState is ClientLoaded) {
      _loadActiveProducts(currentClientState.clients);
    }

    _clientsSubscription = _clientBloc.stream.listen((state) {
      if (state is ClientLoaded && mounted) {
        _loadActiveProducts(state.clients);
      }
    });

    selectedDate = widget.selectedDate ?? DateTime.now();
  }

  /// Параллельно запрашивает активные блоки/абонементы для всех клиентов
  /// с типами 'block' и 'subscription'. Результат кэшируется в [_clientsWithActiveProduct].
  Future<void> _loadActiveProducts(List<Client> clients) async {
    final blockClients = clients
        .where((c) => c.status == 'active' && c.defaultSessionType == 'block')
        .toList();
    final subClients = clients
        .where((c) =>
    c.status == 'active' && c.defaultSessionType == 'subscription')
        .toList();

    if (blockClients.isEmpty && subClients.isEmpty) {
      // Нечего проверять — сбрасываем старый кэш
      if (mounted) setState(() => _clientsWithActiveProduct = {});
      return;
    }

    if (mounted) setState(() => _productsLoading = true);

    try {
      final futures = <Future<MapEntry<String, bool>>>[];

      for (final c in blockClients) {
        futures.add(
          _clientRepository
              .getClientActiveBlock(c.id)
              .then((b) => MapEntry(c.id, b != null)),
        );
      }
      for (final c in subClients) {
        futures.add(
          _clientRepository
              .getClientActiveSubscription(c.id)
              .then((s) => MapEntry(c.id, s != null)),
        );
      }

      final results = await Future.wait(futures);
      final activeIds = results
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      if (mounted) {
        setState(() {
          _clientsWithActiveProduct = activeIds;
          _productsLoading = false;
        });
      }
    } catch (e) {
      // При ошибке не блокируем UI — просто сбрасываем лоадер
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  /// Возвращает true если клиент должен отображаться в дропдауне.
  bool _isClientAvailable(Client c) {
    if (c.status != 'active') return false;
    if (c.defaultSessionType == 'single') return true;
    // block / subscription — только при наличии активного продукта
    return _clientsWithActiveProduct.contains(c.id);
  }

  /// Загружает активную быструю программу клиента (если есть) —
  /// используется, чтобы предложить тренеру выбрать день программы.
  Future<void> _loadActivePlanForClient(String clientId) async {
    setState(() {
      _loadingActivePlan = true;
      _activePlanInfo = null;
      _selectedQuickPlanDay = null;
    });
    try {
      final info = await GetIt.instance<WorkoutPlanRepository>()
          .getActiveQuickPlanInfo(clientId);
      if (!mounted || selectedClientId != clientId) return; // клиента успели сменить
      setState(() {
        _activePlanInfo = info;
        _loadingActivePlan = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingActivePlan = false);
    }
  }

  String _dayLabel(int dayOfWeek) {
    return _activePlanInfo?.dayLabels[dayOfWeek] ?? 'День ${dayOfWeek + 1}';
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _clientsSubscription?.cancel();
    super.dispose();
  }

  bool _canBookSession(DateTime newSessionTime,
      {Duration minInterval = const Duration(hours: 1)}) {
    for (final s in _existingSchedules) {
      final existing = s.scheduledAt.toLocal();
      if (_isSameDay(existing, newSessionTime)) {
        final diff = existing.difference(newSessionTime).inMinutes.abs();
        if (diff < minInterval.inMinutes) return false;
      }
    }
    return true;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _onSave() async {
    if (selectedClient == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите клиента и время')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final localDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    final location = tz.getLocation(_tzName);
    final local = tz.TZDateTime.from(localDateTime, location);
    final utc = local.toUtc();

    final schedule = Schedule(
      scheduledAt: utc,
      timezone: _tzName,
      trainerId: _trainerId,
      clientId: selectedClient!.id,
      sessionType: selectedClient!.defaultSessionType,
      status: 'scheduled',
      workoutPlanId: null,
      workoutDayNumber: null,
      quickPlanId: _selectedQuickPlanDay != null ? _activePlanInfo?.quickPlanId : null,
      quickPlanDayOfWeek: _selectedQuickPlanDay,
      description: description,
    );

    // Диспатчим BookSchedule чтобы ScheduleBloc сделал оптимистичное обновление
    // и экран обновился мгновенно без ожидания Realtime-события.
    // Прямой вызов bookSession.execute() в обход bloc приводил к тому что
    // второй добавленный слот мог появиться только после свёртывания приложения.
    try {
      _scheduleBloc.add(BookSchedule(_trainerId, schedule));

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись успешно добавлена')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка добавления записи: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}';

    return Scaffold(
      appBar: AppBar(title: Text('Запись на $dateStr')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Клиент', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            StreamBuilder<ClientState>(
              stream: _clientBloc.stream,
              initialData: _clientBloc.state,
              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state is ClientLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is ClientLoaded) {
                  // Клиенты с разовыми тренировками — все активные.
                  // Клиенты с блоком/абонементом — только при наличии активного продукта.
                  final clients = state.clients
                      .where(_isClientAvailable)
                      .toList();

                  if (_productsLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (clients.isEmpty) {
                    return Text(
                      'Нет доступных клиентов',
                      style: Theme.of(context).textTheme.labelMedium,
                    );
                  }

                  // Если выбранный клиент более не доступен — сбрасываем выбор
                  final currentIsAvailable =
                      selectedClientId != null &&
                          clients.any((c) => c.id == selectedClientId);
                  if (!currentIsAvailable && selectedClientId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          selectedClientId = null;
                          selectedClient = null;
                          _activePlanInfo = null;
                          _selectedQuickPlanDay = null;
                        });
                      }
                    });
                  }

                  return DropdownButtonFormField<String>(
                    value: currentIsAvailable ? selectedClientId : null,
                    isExpanded: true,
                    decoration:
                    const InputDecoration(border: OutlineInputBorder()),
                    items: clients
                        .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.firstName} ${c.lastName ?? ''}'.trim(),
                        style:
                        Theme.of(context).textTheme.labelMedium,
                      ),
                    ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedClientId = val;
                        selectedClient =
                            clients.firstWhere((c) => c.id == val);
                      });
                      if (val != null) _loadActivePlanForClient(val);
                    },
                  );
                } else if (state is ClientError) {
                  return Text(state.message,
                      style: Theme.of(context).textTheme.labelMedium);
                }
                return const SizedBox();
              },
            ),

            const SizedBox(height: 16),

            if (_loadingActivePlan)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),

            if (_activePlanInfo != null) ...[
              Text(
                'День программы «${_activePlanInfo!.planName}»',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: _selectedQuickPlanDay,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Не привязывать к дню программы',
                ),
                items: _activePlanInfo!.dayNumbers
                    .map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(_dayLabel(d)),
                ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedQuickPlanDay = val),
              ),
              const SizedBox(height: 16),
            ],

            TextButton(
              onPressed: () =>
                  setState(() => scheduleForAnotherDay = !scheduleForAnotherDay),
              child: Text(scheduleForAnotherDay
                  ? 'Запись на выбранный день'
                  : 'Запись на другой день'),
            ),

            if (scheduleForAnotherDay) ...[
              const SizedBox(height: 16),
              _buildDatePicker(context),
            ],

            const SizedBox(height: 16),
            _buildCupertinoTimePicker(context),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  setState(() => needDescription = !needDescription),
              child: Text(
                  needDescription ? 'Убрать заметку' : 'Добавить заметку'),
            ),

            if (needDescription) ...[
              const SizedBox(height: 8),
              _buildScheduleNote(context),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isSaving || isTimeConflict) ? null : _onSave,
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Сохранить'),
              ),
            ),

            const SizedBox(height: 16),
          ],
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
            final firstSelectable =
            DateTime(today.year, today.month, today.day);
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate != null &&
                  selectedDate!.isAfter(firstSelectable)
                  ? selectedDate!
                  : firstSelectable,
              firstDate: firstSelectable,
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() {
                selectedDate = date;
                isTimeConflict = false;
                if (selectedTime != null) {
                  final selectedDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                  isTimeConflict = !_canBookSession(selectedDateTime);
                }
              });
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              selectedDate != null
                  ? '${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}'
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
            TimeOfDay tempTime = selectedTime ?? TimeOfDay.now();
            bool tempConflict = false;

            await showDialog(
              context: context,
              builder: (dialogContext) {
                return StatefulBuilder(
                  builder: (dialogContext, setDialogState) {
                    return AlertDialog(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      content: SizedBox(
                        height: 270,
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
                                    2025,
                                    1,
                                    1,
                                    selectedTime?.hour ??
                                        TimeOfDay.now().hour,
                                    selectedTime?.minute ??
                                        TimeOfDay.now().minute,
                                  ),
                                  onDateTimeChanged: (DateTime dt) {
                                    tempTime = TimeOfDay(
                                        hour: dt.hour, minute: dt.minute);

                                    if (selectedDate != null) {
                                      final selectedDateTime = DateTime(
                                        selectedDate!.year,
                                        selectedDate!.month,
                                        selectedDate!.day,
                                        tempTime.hour,
                                        tempTime.minute,
                                      );
                                      setDialogState(() {
                                        tempConflict =
                                        !_canBookSession(selectedDateTime);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Column(
                                children: [
                                  if (tempConflict)
                                    Text(
                                      'Выбранное время пересекается с другой тренировкой',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: const Text('Отмена'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextButton(
                                          onPressed: tempConflict
                                              ? null
                                              : () =>
                                              Navigator.pop(dialogContext),
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

            if (mounted) {
              setState(() {
                selectedTime = tempTime;
                isTimeConflict = tempConflict;
              });
            }
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
                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                      : 'Выбрать время',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (isTimeConflict)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Выбранное время пересекается с другой тренировкой',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
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
}
