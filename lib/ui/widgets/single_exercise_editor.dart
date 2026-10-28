import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:formeo/presentation/screens/exercise_picker_screen.dart';
//import 'package:formeo/domain/entities/exercise_model.dart';
import 'package:formeo/domain/entities/exercise.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';

class SingleExerciseEditor extends StatefulWidget {
  const SingleExerciseEditor({super.key});

  @override
  State<SingleExerciseEditor> createState() => _SingleExerciseEditorState();
}

class _SingleExerciseEditorState extends State<SingleExerciseEditor> {
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
                      executionType: WorkoutExecutionType.single,
                      maxExercises: 1,
                    ),
                  ),
                );
                //final selectedExercise = await Navigator.push<Exercise>(
                //  context,
                //  MaterialPageRoute(
                //    builder: (context) => ExercisePickerScreen.create(),
                  //),
                //);

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

        const SizedBox(height: 16),

        // ---------------- Расширенные настройки ----------------
        GestureDetector(
          onTap: () {
            setState(() {
              _showAdvanced = !_showAdvanced;
            });
          },
          child: Row(
            children: [
              Text(
                'Расширенные настройки',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
            ],
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _warmupSetsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.labelMedium,
                  decoration: const InputDecoration(
                    labelText: 'Разминочные подходы',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _restController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.labelMedium,
                  decoration: const InputDecoration(
                    labelText: 'Отдых между подходами (сек)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelMedium,
            decoration: const InputDecoration(
              labelText: 'Заметка',
              border: OutlineInputBorder(),
            ),
          ),
        ],

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
