import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coachsly/ui/widgets/circuit_training_editor.dart';
import 'package:coachsly/ui/widgets/superset_training_editor.dart';
import 'package:coachsly/ui/widgets/triset_training_editor.dart';
import 'package:coachsly/ui/widgets/single_exercise_editor.dart';
import 'package:coachsly/ui/widgets/warmup_exercise_editor.dart';

enum WorkoutExecutionType { warmup, single, superset, triset, circuit, cooldown }

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  WorkoutExecutionType _selectedType = WorkoutExecutionType.single;

  void _selectType(WorkoutExecutionType type) {
    setState(() {
      _selectedType = type;
    });
  }

  Widget _buildTypeChips() {
    return Wrap(
      spacing: 8.0,
      children: WorkoutExecutionType.values.map((type) {
        final label = switch (type) {
          WorkoutExecutionType.warmup => 'Разминка',
          WorkoutExecutionType.single => 'Одиночное',
          WorkoutExecutionType.superset => 'Суперсет',
          WorkoutExecutionType.triset => 'Трисет',
          WorkoutExecutionType.circuit => 'Круговая',
          WorkoutExecutionType.cooldown => 'Заминка',
        };
        return ChoiceChip(
          label: Text(label),
          selected: _selectedType == type,
          onSelected: (_) => _selectType(type),
        );
      }).toList(),
    );
  }

  Widget _buildExerciseSettings() {
    switch (_selectedType) {
      case WorkoutExecutionType.warmup:
        return WarmUpExerciseEditor();
      case WorkoutExecutionType.single:
        return SingleExerciseEditor();
      case WorkoutExecutionType.superset:
        return SupersetTrainingEditor();
      case WorkoutExecutionType.triset:
        return TrisetTrainingEditor();
      case WorkoutExecutionType.circuit:
        return CircuitTrainingEditor();
      case WorkoutExecutionType.cooldown:
        return WarmUpExerciseEditor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить упражнение')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Тип выполнения', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTypeChips(),
            const SizedBox(height: 24),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildExerciseSettings(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
