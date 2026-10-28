import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:formeo/presentation/screens/add_exercise_screen.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/presentation/screens/exercise_editor_screen.dart';

class WorkoutDayEditScreen extends StatefulWidget {
  final String planName;
  final WorkoutDay workoutDay;
  final String weekday;
  final int dayOfWeek;

  const WorkoutDayEditScreen({
    super.key,
    required this.planName,
    required this.workoutDay,
    required this.weekday,
    required this.dayOfWeek,
  });

  @override
  State<WorkoutDayEditScreen> createState() => _WorkoutDayEditScreenState();
}

class EmptyExercisesWidget extends StatelessWidget {
  const EmptyExercisesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/icon-workout-screen.svg',
            width: screenWidth * 0.25,
            height: screenHeight * 0.25,
          ),
          const SizedBox(height: 16),
          const Text('Пока нет упражнений'),
        ],
      ),
    );
  }
}

class _WorkoutDayEditScreenState extends State<WorkoutDayEditScreen> {
  late List<WorkoutItem> _items;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _restController =
  TextEditingController(text: '60');

  void _addExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddExerciseScreen(),
      ),
    );

    if (result != null && result is WorkoutItem) {
      if (!mounted) return;
      setState(() {
        _items.add(result);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.workoutDay.items);
    _descriptionController.text = widget.workoutDay.description;
    _restController.text = widget.workoutDay.restBetweenExercises.toString();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _restController.dispose();
    super.dispose();
  }

  // Методы для получения стилей в зависимости от типа упражнения
  Color _getColorForType(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.warmup:
        return Colors.blue.withAlpha(25); // ~10% opacity
      case WorkoutItemType.single:
        return Colors.green.withAlpha(25);
      case WorkoutItemType.superset:
        return Colors.orange.withAlpha(25);
      case WorkoutItemType.triset:
        return Colors.purple.withAlpha(25);
      case WorkoutItemType.circuit:
        return Colors.red.withAlpha(25);
      case WorkoutItemType.cooldown:
        return Colors.teal.withAlpha(25);
    }
  }

  Color _getBorderColorForType(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.warmup:
        return const Color(0xFF1976D2); // Colors.blue[700]
      case WorkoutItemType.single:
        return const Color(0xFF388E3C); // Colors.green[700]
      case WorkoutItemType.superset:
        return const Color(0xFFF57C00); // Colors.orange[700]
      case WorkoutItemType.triset:
        return const Color(0xFF7B1FA2); // Colors.purple[700]
      case WorkoutItemType.circuit:
        return const Color(0xFFD32F2F); // Colors.red[700]
      case WorkoutItemType.cooldown:
        return const Color(0xFF00796B); // Colors.teal[700]
    }
  }

  Color _getTextColorForType(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.warmup:
        return const Color(0xFF0D47A1); // Colors.blue[900]
      case WorkoutItemType.single:
        return const Color(0xFF1B5E20); // Colors.green[900]
      case WorkoutItemType.superset:
        return const Color(0xFFE65100); // Colors.orange[900]
      case WorkoutItemType.triset:
        return const Color(0xFF4A148C); // Colors.purple[900]
      case WorkoutItemType.circuit:
        return const Color(0xFFB71C1C); // Colors.red[900]
      case WorkoutItemType.cooldown:
        return const Color(0xFF004D40); // Colors.teal[900]
    }
  }

  IconData _getIconForType(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.warmup:
        return Icons.thermostat_auto;
      case WorkoutItemType.single:
        return Icons.fitness_center;
      case WorkoutItemType.superset:
        return Icons.layers;
      case WorkoutItemType.triset:
        return Icons.view_agenda;
      case WorkoutItemType.circuit:
        return Icons.cached;
      case WorkoutItemType.cooldown:
        return Icons.air;
    }
  }

  String _getTypeLabel(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.warmup:
        return 'Разминка';
      case WorkoutItemType.single:
        return 'Одиночное';
      case WorkoutItemType.superset:
        return 'Суперсет';
      case WorkoutItemType.triset:
        return 'Трисет';
      case WorkoutItemType.circuit:
        return 'Круговая';
      case WorkoutItemType.cooldown:
        return 'Заминка';
    }
  }

  String _getExerciseCountLabel(WorkoutItem item) {
    switch (item.type) {
      case WorkoutItemType.warmup:
      case WorkoutItemType.single:
      case WorkoutItemType.cooldown:
        return '1 упражнение';
      case WorkoutItemType.superset:
        return '${item.exercises.length} упражнения';
      case WorkoutItemType.triset:
        return '${item.exercises.length} упражнения';
      case WorkoutItemType.circuit:
        return '${item.exercises.length} упражнений';
    }
  }

  // Виджет для отображения группы упражнений
  Widget _buildWorkoutItemCard(WorkoutItem item, int itemIndex) {
    final typeColor = _getColorForType(item.type);
    final borderColor = _getBorderColorForType(item.type);
    final textColor = _getTextColorForType(item.type);
    final icon = _getIconForType(item.type);
    final typeLabel = _getTypeLabel(item.type);
    final countLabel = _getExerciseCountLabel(item);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: typeColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок группы
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:  borderColor.withAlpha(25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    countLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(204),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: textColor),
                    onPressed: () {
                      setState(() {
                        _items.removeAt(itemIndex);
                      });
                    },
                  ),
                ],
              ),
            ),
            // Список упражнений в группе
            ...item.exercises.asMap().entries.map((exerciseEntry) {
              final exerciseIndex = exerciseEntry.key;
              final exercise = exerciseEntry.value;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: borderColor.withAlpha(76),
                      width: 1,
                    ),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: borderColor.withAlpha(51),
                    child: Text(
                      '${exerciseIndex + 1}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    exercise.exercise.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [exercise.exercise.bodyPart, exercise.exercise.difficultyLevel]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exercise.workSets} подх. × ${exercise.reps} повт. • Отдых: ${exercise.restSeconds}с',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (exercise.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Заметка: ${exercise.note}',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.info_outline, color: textColor),
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExerciseEditor(exercise: exercise),
                            ),
                          );

                          if (updated != null && updated is WorkoutExercise) {
                            if (!mounted) return;
                            setState(() {
                              _items[itemIndex].exercises[exerciseIndex] = updated;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: textColor),
                        onPressed: () {
                          setState(() {
                            _items[itemIndex].exercises.removeAt(exerciseIndex);
                            // Если группа пустая, удаляем её
                            if (_items[itemIndex].exercises.isEmpty) {
                              _items.removeAt(itemIndex);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Дополнительная информация о группе
            if (item.restAfterGroup != null && item.restAfterGroup! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: borderColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: textColor),
                    const SizedBox(width: 8),
                    Text(
                      'Отдых после группы: ${item.restAfterGroup}с',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (item.rounds != null && item.rounds! > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: borderColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 16, color: textColor),
                    const SizedBox(width: 8),
                    Text(
                      'Количество кругов: ${item.rounds}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Протокол тренировки: ${widget.weekday} — ${widget.planName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Описание тренировки',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium,
              decoration: const InputDecoration(
                hintText: 'Например: Грудь + дельты + пресс',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Упражнения',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить упражнение'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Легенда типов упражнений
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color:  Color(0xFF2a4066),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: WorkoutItemType.values.map((type) {
                    final borderColor = _getBorderColorForType(type);
                    final textColor = _getTextColorForType(type);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:   Color(0xFFF9FAFB),
                        border: Border.all(color: borderColor, width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(_getIconForType(type), size: 14, color: textColor),
                          const SizedBox(width: 6),
                          Text(
                            _getTypeLabel(type),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _items.isEmpty
                  ? const EmptyExercisesWidget()
                  : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildWorkoutItemCard(_items[index], index);
                },
              ),
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final workoutDay = WorkoutDay(
                      dayOfWeek: widget.dayOfWeek,
                      description: _descriptionController.text,
                      restBetweenExercises:
                      int.tryParse(_restController.text) ?? 60,
                      items: _items,
                    );
                    Navigator.pop(context, workoutDay);
                  },
                  child: const Text('Сохранить тренировку'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}