import 'package:flutter/material.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/core/constants/colors.dart';

class WorkoutPlanDetailScreen extends StatelessWidget {
  final WorkoutPlan plan;

  const WorkoutPlanDetailScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name ?? 'Детали плана'),
        backgroundColor: AppColors.colorBlue,
        foregroundColor: AppColors.colorWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Реализовать редактирование
            },
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildDaysSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      color: AppColors.colorLightBlue.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.colorWhite,
              child: Icon(
                Icons.fitness_center,
                size: 30,
                color: AppColors.colorBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name ?? 'Без названия',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.colorWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (plan.type != null && plan.type!.isNotEmpty)
                    Text(
                      plan.typeLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.colorGrey,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.colorWhite.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Конструктор',
                      style: TextStyle(
                        color: AppColors.colorWhite,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildInfoSection() {
    return Card(
      color: AppColors.colorLightBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о плане',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.colorWhite,
              ),
            ),
            const SizedBox(height: 16),
            _infoTile('Тип тренировки', plan.typeLabel),
            _infoTile('Длительность', _durationLabel(plan.duration)),
            _infoTile('Количество тренировочных дней', '${plan.days.length}'),
            if (plan.createdAt != null)
              _infoTile('Создан', _formatDate(plan.createdAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSection() {
    if (plan.days.isEmpty) {
      return Card(
        color: AppColors.colorLightBlue,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.fitness_center, size: 48, color: AppColors.colorGrey),
              const SizedBox(height: 16),
              const Text(
                'Нет тренировочных дней',
                style: TextStyle(fontSize: 16, color: AppColors.colorWhite),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            'Тренировочные дни',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.colorWhite,
            ),
          ),
        ),
        ...plan.days.map((day) => _buildDayCard(day)).toList(),
      ],
    );
  }

  Widget _buildDayCard(WorkoutDay day) {
    final dayNames = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final dayName = day.dayOfWeek < dayNames.length ? dayNames[day.dayOfWeek] : 'День ${day.dayOfWeek + 1}';

    final shortDayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final shortDayName = day.dayOfWeek < dayNames.length ? shortDayNames[day.dayOfWeek] : 'День ${day.dayOfWeek + 1}';

    return Card(
      color: AppColors.colorLightBlue,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.colorWhite,
                  child: Text(
                    '${shortDayName}',
                    style: TextStyle(
                      color: AppColors.colorBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.colorWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (day.description.isNotEmpty) ...[
              Text(
                day.description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.colorGrey,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildExercisesSection(day),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesSection(WorkoutDay day) {
    final allExercises = day.items.expand((item) => item.exercises).toList();

    if (allExercises.isEmpty) {
      return Text(
        'Нет упражнений',
        style: TextStyle(color: AppColors.colorGrey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Упражнения (${allExercises.length})',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.colorWhite,
          ),
        ),
        const SizedBox(height: 8),
        ...day.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildWorkoutItem(item, index);
        }).toList(),
      ],
    );
  }

  Widget _buildWorkoutItem(WorkoutItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.colorGrey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.colorBlue.withOpacity(0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getItemTypeColor(item.type),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getItemTypeName(item.type),
                  style: const TextStyle(
                    color: AppColors.colorWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (item.rounds != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${item.rounds} кругов',
                  style: const TextStyle(fontSize: 12, color: AppColors.colorWhite),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...item.exercises.map((exercise) => _buildExerciseTile(exercise)).toList(),
          if (item.restAfterGroup != null) ...[
            const SizedBox(height: 8),
            Text(
              'Отдых после группы: ${item.restAfterGroup} сек',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.colorGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseTile(WorkoutExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.colorBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.colorWhite,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.colorWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildSetInfo('Подходы', '${exercise.workSets}'),
                    const SizedBox(width: 12),
                    _buildSetInfo('Повторения', '${exercise.reps}'),
                    if (exercise.warmupSets > 0) ...[
                      const SizedBox(width: 12),
                      _buildSetInfo('Разминка', '${exercise.warmupSets}'),
                    ],
                    if (exercise.restSeconds > 0) ...[
                      const SizedBox(width: 12),
                      _buildSetInfo('Отдых', '${exercise.restSeconds}с'),
                    ],
                  ],
                ),
                if (exercise.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.note,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.colorGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.colorWhite,
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.colorWhite),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.colorWhite,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  /// duration хранится в днях — добавляем склонение день/дня/дней
  /// (тот же алгоритм, что и в universal_card.dart).
  String _durationLabel(int? duration) {
    if (duration == null) return 'Не указана';
    final mod10 = duration % 10;
    final mod100 = duration % 100;
    if (mod10 == 1 && mod100 != 11) return '$duration день';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
      return '$duration дня';
    }
    return '$duration дней';
  }

  Color _getItemTypeColor(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.warmup:
        return Colors.blue.shade700;
      case WorkoutItemType.single:
        return Colors.green.shade700;
      case WorkoutItemType.superset:
        return AppColors.colorRed;
      case WorkoutItemType.triset:
        return Colors.purple.shade700;
      case WorkoutItemType.circuit:
        return AppColors.colorDarkRed;
      case WorkoutItemType.cooldown:
        return Colors.teal.shade700;
    }
  }

  String _getItemTypeName(WorkoutItemType type) {
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
        return 'Круговое';
      case WorkoutItemType.cooldown:
        return 'Заминка';
    }
  }
}