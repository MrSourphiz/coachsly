import 'package:flutter/material.dart';
import 'package:coachsly/domain/entities/exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  // Метод для получения иконки для типа оборудования
  IconData _getEquipmentIcon(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'barbell':
        return Icons.fitness_center;
      case 'dumbbell':
        return Icons.sports_gymnastics;
      case 'body only':
      case 'bodyweight':
        return Icons.self_improvement;
      case 'machine':
        return Icons.build;
      case 'cable':
        return Icons.cable;
      case 'kettlebells':
        return Icons.sports;
      case 'bands':
        return Icons.extension;
      case 'medicine ball':
        return Icons.sports_baseball;
      case 'exercise ball':
        return Icons.sports_basketball;
      case 'foam roll':
        return Icons.roller_skating;
      default:
        return Icons.fitness_center;
    }
  }

  // Метод для получения цвета сложности
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'expert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Метод для получения иконки мышечной группы
  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Icons.self_improvement;
      case 'back':
      case 'lats':
      case 'traps':
        return Icons.airline_seat_flat;
      case 'shoulders':
        return Icons.accessible_forward;
      case 'biceps':
      case 'triceps':
      case 'forearms':
//        return Icons.flex_direction;
      case 'abdominals':
      case 'abductors':
      case 'adductors':
        return Icons.person_outline;
      case 'quadriceps':
      case 'hamstrings':
      case 'glutes':
      case 'calves':
        return Icons.directions_run;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    final theme = Theme.of(context);
    final blockBackgroundColor = const Color(0xFF2a4066);
    final textColor = const Color(0xFFF9FAFB);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ex.title ?? 'Упражнение',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Основная информация в карточке
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              color: blockBackgroundColor, // Добавлен цвет фона
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок
                    Text(
                      ex.title ?? 'Без названия',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor, // Изменен цвет текста
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Сетка с основной информацией
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3,
                      children: [
                        // Категория
                        _buildInfoItem(
                          icon: Icons.category,
                          label: 'Категория',
                          value: ex.category ?? 'Не указана',
                          context: context,
                          backgroundColor: blockBackgroundColor,
                          textColor: textColor,
                        ),
                        // Мышечная группа
                        _buildInfoItem(
                          icon: _getMuscleGroupIcon(ex.bodyPart ?? ''),
                          label: 'Мышечная группа',
                          value: ex.bodyPart ?? 'Не указана',
                          context: context,
                          backgroundColor: blockBackgroundColor,
                          textColor: textColor,
                        ),
                        // Оборудование
                        _buildInfoItem(
                          icon: _getEquipmentIcon(ex.equipment ?? ''),
                          label: 'Оборудование',
                          value: ex.equipment ?? 'Не указано',
                          context: context,
                          backgroundColor: blockBackgroundColor,
                          textColor: textColor,
                        ),
                        // Сложность
                        Container(
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(ex.difficultyLevel ?? '')
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getDifficultyColor(ex.difficultyLevel ?? ''),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.speed,
                                color: _getDifficultyColor(ex.difficultyLevel ?? ''),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Сложность',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: textColor, // Изменен цвет текста
                                      ),
                                    ),
                                    Text(
                                      ex.difficultyLevel ?? 'Не указана',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: _getDifficultyColor(ex.difficultyLevel ?? ''),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Раздел с описанием
            if (ex.description?.isNotEmpty == true) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Описание',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: blockBackgroundColor, // Цвет как у блоков
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 2,
                color: blockBackgroundColor, // Добавлен цвет фона
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    ex.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: textColor, // Изменен цвет текста
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  // Обновленный вспомогательный метод для создания элементов информации
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor, // Изменен цвет иконки
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor.withOpacity(0.8), // Изменен цвет текста
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor, // Изменен цвет текста
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}