import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
//import 'package:formeo/domain/entities/exercise_model.dart';
import 'package:formeo/domain/entities/exercise.dart';
import 'package:formeo/presentation/screens/exercise_picker_screen.dart';

class CircuitTrainingEditor extends StatefulWidget {
  const CircuitTrainingEditor({super.key});

  @override
  State<CircuitTrainingEditor> createState() => _CircuitTrainingEditorState();
}

class _CircuitTrainingEditorState extends State<CircuitTrainingEditor> {
  int _exerciseCount = 3;

  final List<Exercise?> _selectedExercises = [];
  final List<TextEditingController> _repsControllers = [];
  final List<TextEditingController> _weightControllers = [];
  final List<TextEditingController> _workSetsController = [];

  final TextEditingController _roundsController = TextEditingController();
  final TextEditingController _restBetweenRoundsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeControllers(_exerciseCount);
  }

  void _initializeControllers(int count) {
    for (final c in _repsControllers) c.dispose();
    for (final c in _weightControllers) c.dispose();
    for (final c in _workSetsController) c.dispose();

    _selectedExercises
      ..clear()
      ..addAll(List.generate(count, (_) => null));

    _repsControllers
      ..clear()
      ..addAll(List.generate(count, (_) => TextEditingController()));

    _workSetsController
      ..clear()
      ..addAll(List.generate(count, (_) => TextEditingController()));

    _weightControllers
      ..clear()
      ..addAll(List.generate(count, (_) => TextEditingController()));
  }

  void _changeExerciseCount(int newCount) {
    setState(() {
      _exerciseCount = newCount;
      _initializeControllers(newCount);
    });
  }

  void _pickExercise(int index) async {
    final selectedExercises = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) => ExercisePickerScreen.create(
          executionType: WorkoutExecutionType.circuit,
          maxExercises: _exerciseCount,
        ),
      ),
    );

    if (selectedExercises != null && selectedExercises.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        // Заполняем оба слота упражнениями
        for (int i = 0; i < selectedExercises.length && i < _exerciseCount; i++) {
          _selectedExercises[i] = selectedExercises[i];
        }
      });
    }
  }

  void _saveCircuit() {
    if (_selectedExercises.any((ex) => ex == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите все упражнения для круга')),
      );
      return;
    }

    final exercises = List.generate(_exerciseCount, (index) {
      return WorkoutExercise(
        id: _selectedExercises[index]!.id,
        name: _selectedExercises[index]!.title,
        exercise: _selectedExercises[index]!,
        note: '',
        restSeconds: 0,
        warmupSets: 0,
        workSets: int.tryParse(_roundsController.text) ?? 0,
        reps: int.tryParse(_repsControllers[index].text) ?? 0,
        //  weight: double.tryParse(_weightControllers[index].text),
      );
    });

    final workoutItem = WorkoutItem(
      type: WorkoutItemType.circuit,
      exercises: exercises,
      restAfterGroup: int.tryParse(_restBetweenRoundsController.text) ?? 0,
    );

    Navigator.pop(context, workoutItem);
  }

  @override
  void dispose() {
    for (final c in _repsControllers) c.dispose();
    for (final c in _weightControllers) c.dispose();
    _roundsController.dispose();
    _restBetweenRoundsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Количество упражнений:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _exerciseCount,
                  onChanged: (value) {
                    if (value != null) _changeExerciseCount(value);
                  },
                  items: List.generate(10, (i) => i + 1)
                      .map((count) => DropdownMenuItem(
                    value: count,
                    child: Text('$count'),
                  ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _exerciseCount,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              _selectedExercises[index]?.title ??
                                  'Выбрать упражнение ${index + 1}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _pickExercise(index),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _repsControllers[index],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: Theme.of(context).textTheme.labelMedium,
                                  decoration: const InputDecoration(
                                    labelText: 'Повторы',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
//                              const SizedBox(width: 12),
//                              Expanded(
//                                child: TextField(
//                                  controller: _weightControllers[index],
//                                  keyboardType: TextInputType.number,
//                                  inputFormatters: [
//                                    FilteringTextInputFormatter.digitsOnly
//                                  ],
//                                  style: Theme.of(context).textTheme.labelMedium,
//                                  decoration: const InputDecoration(
//                                    labelText: 'Вес / интенсивность',
//                                    border: OutlineInputBorder(),
//                                  ),
//                                ),
//                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roundsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.labelMedium,
                    decoration: const InputDecoration(
                      labelText: 'Количество кругов',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _restBetweenRoundsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.labelMedium,
                    decoration: const InputDecoration(
                      labelText: 'Отдых между кругами (сек)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _saveCircuit,
                child: const Text('Сохранить тренировку'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
