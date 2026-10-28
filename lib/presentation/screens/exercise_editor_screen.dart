import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:formeo/domain/entities/workout_exercise.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';


class ExerciseEditor extends StatefulWidget {
  final WorkoutExercise exercise;

  const ExerciseEditor({super.key, required this.exercise});

  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  late TextEditingController _noteController;
  late TextEditingController _restController;
  late TextEditingController _warmupSetsController;
  late TextEditingController _workSetsController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.exercise.note);
    _restController = TextEditingController(text: widget.exercise.restSeconds.toString());
    _warmupSetsController = TextEditingController(text: widget.exercise.warmupSets.toString());
    _workSetsController = TextEditingController(text: widget.exercise.workSets.toString());
    _repsController = TextEditingController(text: widget.exercise.reps.toString());
  }

  @override
  void dispose() {
    _noteController.dispose();
    _restController.dispose();
    _warmupSetsController.dispose();
    _workSetsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = WorkoutExercise(
      id: widget.exercise.id,
      name: widget.exercise.exercise.title,
      exercise: widget.exercise.exercise,
      note: _noteController.text,
      restSeconds: int.tryParse(_restController.text) ?? 60,
      warmupSets: int.tryParse(_warmupSetsController.text) ?? 0,
      workSets: int.tryParse(_workSetsController.text) ?? 0,
      reps: int.tryParse(_repsController.text) ?? 0,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Редактировать упражнение')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(widget.exercise.exercise.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium,
              decoration: const InputDecoration(labelText: 'Заметка', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _restController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.labelMedium,
              decoration: const InputDecoration(labelText: 'Отдых между подходами (сек)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _warmupSetsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.labelMedium,
              decoration: const InputDecoration(labelText: 'Размин. подходы', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workSetsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.labelMedium,
              decoration: const InputDecoration(labelText: 'Раб. подходы', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.labelMedium,
              decoration: const InputDecoration(labelText: 'Повторения', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
