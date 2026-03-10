import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coachsly/presentation/screens/exercise_picker_screen.dart';
//import 'package:coachsly/domain/entities/exercise_model.dart';
import 'package:coachsly/domain/entities/exercise.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';

class WarmUpExerciseEditor extends StatefulWidget {
  const WarmUpExerciseEditor({super.key});

  @override
  State<WarmUpExerciseEditor> createState() => _WarmUpExerciseEditorState();
}

class _WarmUpExerciseEditorState extends State<WarmUpExerciseEditor> {
  final List<String?> _exercises = [null];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  final TextEditingController _warmupSetsController = TextEditingController();
  final TextEditingController _workSetsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  Exercise? _selectedExercise;

  bool _showAdvanced = false; // флаг для расширенных настроек

  @override
  void dispose() {
    _noteController.dispose();
    _restController.dispose();
    _warmupSetsController.dispose();
    _workSetsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ListView.builder(
          itemCount: _exercises.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => Card(
            child: ListTile(
              title: Text(_exercises[index] ?? 'Выбрать упражнение'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final selectedExercises = await Navigator.push<List<Exercise>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExercisePickerScreen.create(
                      executionType: WorkoutExecutionType.warmup,
                      maxExercises: 1,
                    ),
                  ),
                );

                if (selectedExercises != null) {
                  setState(() {
                    _selectedExercise = selectedExercises.first;
                    _exercises[index] = selectedExercises.first.title;
                  });
                }
              },
            ),
          ),
        ),
        const Divider(height: 32),

        // ---------------- Базовые настройки ----------------
        const Text('Базовые настройки', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _workSetsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.labelMedium,
                decoration: const InputDecoration(
                  labelText: 'Рабочие подходы',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.labelMedium,
                decoration: const InputDecoration(
                  labelText: 'Повторения',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: () {
              if (_selectedExercise == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Выберите упражнение')),
                );
                return;
              }

              final workoutExercise = WorkoutExercise(
                id: _selectedExercise!.id,
                name: _selectedExercise!.title,
                exercise: _selectedExercise!,
                note: _noteController.text,
                restSeconds: int.tryParse(_restController.text) ?? 0,
                warmupSets: int.tryParse(_warmupSetsController.text) ?? 0,
                workSets: int.tryParse(_workSetsController.text) ?? 0,
                reps: int.tryParse(_repsController.text) ?? 0,
              );

              final workoutItem = WorkoutItem(
                type: WorkoutItemType.single,
                exercises: [workoutExercise],
              );

              Navigator.pop(context, workoutItem);
            },
            child: const Text('Сохранить упражнение'),
          ),
        ),
      ],
    );
  }
}
