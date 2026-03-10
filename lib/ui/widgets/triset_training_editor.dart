import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
//import 'package:coachsly/domain/entities/exercise_model.dart';
import 'package:coachsly/domain/entities/exercise.dart';
import 'package:coachsly/presentation/screens/exercise_picker_screen.dart';

class TrisetTrainingEditor extends StatefulWidget {
  const TrisetTrainingEditor({super.key});

  @override
  State<TrisetTrainingEditor> createState() => _TrisetTrainingEditorState();
}

class _TrisetTrainingEditorState extends State<TrisetTrainingEditor> {
  final List<Exercise?> _selectedExercises = [null, null, null];
  late final List<TextEditingController> _repsControllers;
  late final List<TextEditingController> _weightControllers;
  late final List<TextEditingController> _workSetsController;

  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _restAfterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _workSetsController= List.generate(3, (_) => TextEditingController());
    _repsControllers = List.generate(3, (_) => TextEditingController());
    _weightControllers = List.generate(3, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (var c in _repsControllers) c.dispose();
    for (var c in _weightControllers) c.dispose();
    for (var c in _workSetsController) c.dispose();
    _setsController.dispose();
    _restAfterController.dispose();

    super.dispose();
  }

  void _pickExercise(int index) async {
    final selectedExercises = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) => ExercisePickerScreen.create(
          executionType: WorkoutExecutionType.triset,
          maxExercises: 3,
        ),
      ),
    );

    if (selectedExercises != null && selectedExercises.isNotEmpty) {
      setState(() {
        // Заполняем оба слота упражнениями
        for (int i = 0; i < selectedExercises.length && i < 3; i++) {
          _selectedExercises[i] = selectedExercises[i];
        }
      });
    }
  }

  void _saveTriset() {
    if (_selectedExercises.any((ex) => ex == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите все упражнения для трисета')),
      );
      return;
    }

    final exercises = List.generate(3, (index) {
      return WorkoutExercise(
        id: _selectedExercises[index]!.id,
        name: _selectedExercises[index]!.title,
        exercise: _selectedExercises[index]!,
        note: '',
        restSeconds: 0, // отдых внутри трисета можно добавить позже
        warmupSets: 0,
        workSets: int.tryParse(_setsController.text) ?? 0,
        reps: int.tryParse(_repsControllers[index].text) ?? 0,
        //weight: double.tryParse(_weightControllers[index].text),
      );
    });

    final workoutItem = WorkoutItem(
      type: WorkoutItemType.triset,
      exercises: exercises,
      restAfterGroup: int.tryParse(_restAfterController.text) ?? 0,
    );

    Navigator.pop(context, workoutItem);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...List.generate(3, (index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      _selectedExercises[index]?.title ??
                          'Выбрать упражнение ${String.fromCharCode(65 + index)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickExercise(index),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _workSetsController[index],
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
                          controller: _repsControllers[index],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: Theme.of(context).textTheme.labelMedium,
                          decoration: InputDecoration(
                            labelText:
                            'Повторения ${String.fromCharCode(65 + index)}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
//                      const SizedBox(width: 12),
//                      Expanded(
//                        child: TextField(
//                          controller: _weightControllers[index],
//                          keyboardType: TextInputType.number,
//                          style: Theme.of(context).textTheme.labelMedium,
//                          decoration: InputDecoration(
//                            labelText:
//                            'Вес ${String.fromCharCode(65 + index)} (кг)',
//                            border: const OutlineInputBorder(),
//                          ),
//                        ),
//                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _setsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.labelMedium,
                decoration: const InputDecoration(
                  labelText: 'Кол-во трисетов',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _restAfterController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.labelMedium,
                decoration: const InputDecoration(
                  labelText: 'Отдых после (сек)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: _saveTriset,
            child: const Text('Сохранить трисет'),
          ),
        )
      ],
    );
  }
}
