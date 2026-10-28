import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/domain/entities/workout_log.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/repositories/workout_log_repository.dart';
import 'package:formeo/ui/widgets/app_text_field.dart';

/// Экран фиксации прогресса клиента прямо во время тренировки.
/// Открывается с карточки подтверждённой тренировки на дашборде
/// (см. TodayScheduleScreen) или из истории клиента.
class WorkoutLogScreen extends StatefulWidget {
  final Schedule schedule;

  const WorkoutLogScreen({super.key, required this.schedule});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

/// Локальное редактируемое состояние одного подхода — контроллеры полей
/// живут здесь, а не в WorkoutLogSet, чтобы не пересоздавать TextField
/// при каждом изменении текста.
class _EditableSet {
  final int setNumber;
  final TextEditingController repsController;
  final TextEditingController weightController;
  String? savedSetId; // id уже сохранённой строки в workout_log_sets, если есть

  _EditableSet({
    required this.setNumber,
    String? initialReps,
    String? initialWeight,
    this.savedSetId,
  })  : repsController = TextEditingController(text: initialReps),
        weightController = TextEditingController(text: initialWeight);

  void dispose() {
    repsController.dispose();
    weightController.dispose();
  }
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final _repo = GetIt.instance<WorkoutLogRepository>();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  WorkoutLog? _workoutLog;
  List<QuickPlanExercise> _exercises = [];
  final Map<String, List<_EditableSet>> _setsByExercise = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final sets in _setsByExercise.values) {
      for (final s in sets) {
        s.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = widget.schedule;
    final quickPlanId = s.quickPlanId;
    final dayOfWeek = s.quickPlanDayOfWeek;

    if (quickPlanId == null || dayOfWeek == null) {
      setState(() {
        _loading = false;
        _error = 'Эта тренировка не привязана к дню программы';
      });
      return;
    }

    try {
      final log = await _repo.getOrCreateWorkoutLog(
        trainerId: s.trainerId,
        clientId: s.clientId,
        bookingId: s.id,
        quickPlanId: quickPlanId,
        dayOfWeek: dayOfWeek,
        performedAt: s.scheduledAt.toLocal(),
      );

      final exercises = await _repo.getPlanExercisesForDay(quickPlanId, dayOfWeek);
      final existingSets = await _repo.getWorkoutLogSets(log.id);

      final byExercise = <String, List<_EditableSet>>{};
      for (final ex in exercises) {
        final exerciseId = ex.id;
        if (exerciseId == null) continue;
        final rows = <_EditableSet>[];
        for (var setNumber = 1; setNumber <= ex.workSets; setNumber++) {
          final existing = existingSets.where(
                (e) => e.quickPlanExerciseId == exerciseId && e.setNumber == setNumber,
          );
          if (existing.isNotEmpty) {
            final e = existing.first;
            rows.add(_EditableSet(
              setNumber: setNumber,
              initialReps: e.repsActual?.toString(),
              initialWeight: e.weightActual?.toString(),
              savedSetId: e.id,
            ));
          } else {
            rows.add(_EditableSet(setNumber: setNumber));
          }
        }
        byExercise[exerciseId] = rows;
      }

      if (!mounted) return;
      setState(() {
        _workoutLog = log;
        _exercises = exercises;
        _setsByExercise
          ..clear()
          ..addAll(byExercise);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка загрузки: $e';
      });
    }
  }

  Future<bool> _persistAllSets() async {
    final log = _workoutLog;
    if (log == null) return false;

    try {
      for (final entry in _setsByExercise.entries) {
        final exerciseId = entry.key;
        for (final row in entry.value) {
          // Сохраняем только те строки, где тренер что-то заполнил —
          // пустые заготовки не засоряют базу.
          final reps = int.tryParse(row.repsController.text.trim());
          final weight = double.tryParse(row.weightController.text.trim().replaceAll(',', '.'));
          if (reps == null && weight == null && row.savedSetId == null) {
            continue;
          }
          final saved = await _repo.upsertWorkoutLogSet(WorkoutLogSet(
            id: row.savedSetId,
            workoutLogId: log.id,
            quickPlanExerciseId: exerciseId,
            setNumber: row.setNumber,
            repsActual: reps,
            weightActual: weight,
          ));
          row.savedSetId = saved.id;
        }
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
      return false;
    }
  }

  Future<void> _onSave({required bool complete}) async {
    setState(() => _saving = true);
    final ok = await _persistAllSets();
    if (ok && complete && _workoutLog != null) {
      try {
        await _repo.completeWorkoutLog(_workoutLog!.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Подходы сохранены, но не удалось завершить тренировку: $e')),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(complete ? 'Тренировка завершена' : 'Прогресс сохранён')),
      );
      if (complete) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = _exercises.isNotEmpty
        ? _exercises.first.displayDayLabel
        : (widget.schedule.quickPlanDayOfWeek != null
        ? 'День ${widget.schedule.quickPlanDayOfWeek! + 1}'
        : '');

    return Scaffold(
      appBar: AppBar(
        title: Text(dayLabel.isNotEmpty ? 'Тренировка · $dayLabel' : 'Тренировка'),
        backgroundColor: AppColors.colorBlue,
        foregroundColor: AppColors.colorWhite,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _exercises.length,
        itemBuilder: (context, index) => _buildExerciseCard(_exercises[index]),
      ),
      bottomNavigationBar: (_loading || _error != null)
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _onSave(complete: false),
                  child: const Text('Сохранить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _onSave(complete: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorBlue,
                    foregroundColor: AppColors.colorWhite,
                  ),
                  child: _saving
                      ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Завершить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(QuickPlanExercise exercise) {
    final rows = _setsByExercise[exercise.id] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.colorLightBlue,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.customName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.colorWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Цель: ${exercise.workSets} × ${exercise.reps}',
              style: TextStyle(fontSize: 12, color: AppColors.colorGrey),
            ),
            const SizedBox(height: 10),
            ...rows.map((row) => _buildSetRow(row)),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(_EditableSet row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text('${row.setNumber}', style: const TextStyle(color: AppColors.colorWhite)),
          ),
          Expanded(
            child: AppTextField(
              label: 'Повторения',
              controller: row.repsController,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              label: 'Вес, кг',
              controller: row.weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    );
  }
}
