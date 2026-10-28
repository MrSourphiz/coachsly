import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/entities/assigned_quick_plan.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/usecases/assign_quick_workout_plan.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

class AssignQuickWorkoutPlanScreen extends StatefulWidget {
  final QuickWorkoutPlan plan;
  const AssignQuickWorkoutPlanScreen({super.key, required this.plan});

  @override
  State<AssignQuickWorkoutPlanScreen> createState() => _AssignQuickWorkoutPlanScreenState();
}

class _AssignQuickWorkoutPlanScreenState extends State<AssignQuickWorkoutPlanScreen> {
  List<Client> _clients = [];
  Client? _selectedClient;
  DateTime _startDate = DateTime.now();
  bool _loadingClients = true;
  bool _saving = false;

  // Дни тренировок и длительность не выбираются вручную — берём их из самой
  // программы. Дни программы больше не привязаны к дням недели: это могут
  // быть как реальные дни ("Понедельник"), так и произвольные метки
  // ("Спина-Трицепс") — то, что тренер использовал в тексте программы.
  // Именно эти метки и сохраняются в assigned_quick_plans.training_days —
  // поле теперь чисто описательное, не ключи недели.
  late final List<String> _planDayLabels;
  late final int? _planDurationWeeks;

  String? _existingActivePlanName;
  bool _checkingActivePlan = false;

  @override
  void initState() {
    super.initState();
    _planDayLabels = _extractPlanDayLabels(widget.plan);

    final durationDays = widget.plan.duration;
    _planDurationWeeks = (durationDays != null && durationDays > 0)
        ? (durationDays / 7).ceil()
        : null;

    _loadClients();
  }

  /// Метки дней программы в порядке их индекса (dayOfWeek), без дублей.
  /// Основной источник — parsed_data.days (всегда заполнено для
  /// сохранённого плана), запасной — plan.exercises (если объект пришёл
  /// с уже подгруженным списком упражнений другим путём).
  List<String> _extractPlanDayLabels(QuickWorkoutPlan plan) {
    final Map<int, String> byIndex = {};

    final parsedDays = plan.parsedData?['days'];
    if (parsedDays is List) {
      for (final d in parsedDays) {
        final map = d as Map;
        final idx = map['dayOfWeek'];
        if (idx is int) {
          final label = map['dayLabel'] as String?;
          byIndex[idx] = (label != null && label.trim().isNotEmpty) ? label : 'День ${idx + 1}';
        }
      }
    }

    if (byIndex.isEmpty && plan.exercises.isNotEmpty) {
      for (final e in plan.exercises) {
        byIndex[e.dayOfWeek] = e.displayDayLabel;
      }
    }

    final sortedIndices = byIndex.keys.toList()..sort();
    return sortedIndices.map((i) => byIndex[i]!).toList();
  }

  Future<void> _loadClients() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final clients = await GetIt.instance<ClientRepository>().fetchClients(user.id);
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _loadingClients = false;
    });
  }

  Future<void> _onClientSelected(Client? client) async {
    setState(() {
      _selectedClient = client;
      _existingActivePlanName = null;
    });
    if (client == null) return;

    setState(() => _checkingActivePlan = true);
    final planName = await GetIt.instance<WorkoutPlanRepository>()
        .getActiveQuickPlanName(client.id);
    if (!mounted || _selectedClient?.id != client.id) return;
    setState(() {
      _existingActivePlanName = planName;
      _checkingActivePlan = false;
    });
  }

  Future<void> _submit() async {
    final user = context.read<UserProvider>().user;
    if (user == null || _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите клиента')),
      );
      return;
    }

    if (_planDayLabels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В программе не удалось определить дни тренировок')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await GetIt.instance<AssignQuickWorkoutPlan>().execute(
        AssignedQuickPlan(
          id: '',
          trainerId: user.id,
          clientId: _selectedClient!.id,
          quickPlanId: widget.plan.id!,
          startDate: _startDate,
          trainingDays: _planDayLabels,
          durationWeeks: _planDurationWeeks,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Программа назначена клиенту ${_selectedClient!.firstName}')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Назначить программу'),
        backgroundColor: AppColors.colorBlue,
        foregroundColor: AppColors.colorWhite,
      ),
      body: _loadingClients
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.plan.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Дни и длительность программы — read-only, берутся из самой
          // программы, а не выбираются тренером отдельно.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_view_week, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _planDayLabels.isEmpty
                            ? 'Дни тренировок не определены'
                            : 'Дни программы: ${_planDayLabels.join(', ')}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timelapse, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _planDurationWeeks != null
                          ? 'Длительность: $_planDurationWeeks нед. (${widget.plan.duration} дн.)'
                          : 'Длительность: бессрочно',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Клиент', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<Client>(
            value: _selectedClient,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: const Text('Выберите клиента'),
            items: _clients.map((c) => DropdownMenuItem(
              value: c,
              child: Text('${c.firstName} ${c.lastName ?? ""}'),
            )).toList(),
            onChanged: _onClientSelected,
          ),
          const SizedBox(height: 20),

          if (_checkingActivePlan)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          if (_existingActivePlanName != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'У клиента уже назначена программа «$_existingActivePlanName» — она будет заменена новой.',
                      style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          const Text('Дата начала', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
            child: Text('${_startDate.day}.${_startDate.month}.${_startDate.year}'),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Назначить'),
            ),
          ),
        ],
      ),
    );
  }
}
