import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formeo/presentation/blocs/training_diary_bloc.dart';

class TrainingDiaryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Дневник тренировок')),
      body: BlocBuilder<TrainingDiaryBloc, TrainingDiaryState>(
        builder: (context, state) {
          if (state is TrainingDiaryInitial) {
            return Center(
                child: Text(
                    'Дневник еще не загружен',
                    style: Theme.of(context).textTheme.bodyLarge,
                ),
            );
          } else if (state is TrainingDiaryLoading) {
            return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
            );
          } else if (state is TrainingDiarySuccess) {
            return ListView.builder(
              itemCount: state.entries.length,
              itemBuilder: (context, index) {
                final entry = state.entries[index];
                return ListTile(
                  title: Text(
                      entry.date.toString(),
                      style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                      '${entry.workoutType} - ${entry.durationMinutes} мин',
                      style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            );
          } else if (state is TrainingDiaryError) {
            return Center(
                child: Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                ),
            );
          }
          return const SizedBox.shrink(); // На случай, если состояние не определено
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Логика для добавления новой записи
          _showAddDialog(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final workoutTypeController = TextEditingController();
    final durationController = TextEditingController();
    final notesController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Добавить запись',
          style: Theme.of(context).dialogTheme.titleTextStyle,
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: workoutTypeController,
                decoration: const InputDecoration(labelText: 'Тип тренировки'),
                style: Theme.of(context).textTheme.bodyMedium,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите тип тренировки';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Длительность (мин)'),
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyMedium,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите длительность';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Введите корректное число';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Заметки (опционально)'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // TODO: Добавить команду для TrainingDiaryBloc
                Navigator.pop(context);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

