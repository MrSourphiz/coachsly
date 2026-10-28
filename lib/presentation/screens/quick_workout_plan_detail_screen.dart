import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/entities/assigned_quick_plan.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/core/constants/colors.dart';

class QuickWorkoutPlanDetailScreen extends StatefulWidget {
  final QuickWorkoutPlan plan;

  const QuickWorkoutPlanDetailScreen({super.key, required this.plan});

  @override
  State<QuickWorkoutPlanDetailScreen> createState() => _QuickWorkoutPlanDetailScreenState();
}

class _QuickWorkoutPlanDetailScreenState extends State<QuickWorkoutPlanDetailScreen> {
  late Future<List<AssignedPlanClient>> _assignedClientsFuture;

  QuickWorkoutPlan get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _assignedClientsFuture = plan.id == null
        ? Future.value(<AssignedPlanClient>[])
        : GetIt.instance<WorkoutPlanRepository>().getClientsForQuickPlan(plan.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        backgroundColor: AppColors.colorBlue,
        foregroundColor: AppColors.colorWhite,
        /*
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Реализовать редактирование быстрого плана
            },
          ),
        ],
         */
      ),
      body: _buildContent(),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Назначить клиенту'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorBlue,
              foregroundColor: AppColors.colorWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: plan.id == null
                ? null
                : () async {
              final assigned = await context.pushNamed<bool>(
                'assignQuickWorkoutPlan',
                extra: plan,
              );
              // После успешного назначения обновляем список клиентов
              // прямо на этом экране, не заставляя тренера возвращаться
              // к списку программ и заходить в детали заново.
              if (assigned == true && mounted) {
                setState(() {
                  _assignedClientsFuture = GetIt.instance<WorkoutPlanRepository>()
                      .getClientsForQuickPlan(plan.id!);
                });
              }
            },
          ),
        ),
      ),
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
          _buildAssignedClientsSection(),
          const SizedBox(height: 24),
          _buildExercisesSection(),
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
                Icons.flash_on,
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
                    plan.name,
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
                      'Быстрая загрузка',
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
            if (plan.schedule != null && plan.schedule!.isNotEmpty)
              _infoTile('Расписание', plan.schedule!),
            if (plan.selectedDays != null && plan.selectedDays!.isNotEmpty)
              _infoTile('Выбранные дни', plan.selectedDays!.join(', ')),
            _infoTile('Количество упражнений', _getTotalExercisesCount().toString()),
            if (plan.createdAt != null)
              _infoTile('Создан', _formatDate(plan.createdAt!)),
            if (plan.updatedAt != null)
              _infoTile('Обновлен', _formatDate(plan.updatedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedClientsSection() {
    return FutureBuilder<List<AssignedPlanClient>>(
      future: _assignedClientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: AppColors.colorLightBlue,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final clients = snapshot.data ?? [];

        return Card(
          color: AppColors.colorLightBlue,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Назначена клиентам',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorWhite,
                  ),
                ),
                const SizedBox(height: 12),
                if (clients.isEmpty)
                  Row(
                    children: [
                      Icon(Icons.person_off_outlined, size: 20, color: AppColors.colorGrey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Программа пока никому не назначена',
                          style: TextStyle(fontSize: 14, color: AppColors.colorGrey),
                        ),
                      ),
                    ],
                  )
                else
                  ...clients.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.colorWhite,
                          child: Text(
                            c.clientName.isNotEmpty ? c.clientName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: AppColors.colorBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.clientName.isNotEmpty ? c.clientName : 'Без имени',
                            style: const TextStyle(fontSize: 14, color: AppColors.colorWhite),
                          ),
                        ),
                        Text(
                          _formatDate(c.startDate),
                          style: TextStyle(fontSize: 12, color: AppColors.colorGrey),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercisesSection() {
    // Проверяем, есть ли данные в parsedData
    final hasParsedData = plan.parsedData != null &&
        plan.parsedData!['days'] != null &&
        (plan.parsedData!['days'] as List).isNotEmpty;

    // Проверяем, есть ли данные в exercises
    final hasExercises = plan.exercises.isNotEmpty;

    if (!hasParsedData && !hasExercises) {
      return Card(
        color: AppColors.colorLightBlue,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.fitness_center, size: 48, color: AppColors.colorGrey),
              const SizedBox(height: 16),
              const Text(
                'Нет упражнений',
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
            'Упражнения по дням',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.colorWhite,
            ),
          ),
        ),

        // Отображаем данные из parsedData, если они есть
        if (hasParsedData)
          ..._buildDaysFromParsedData(),

        // Или отображаем данные из exercises, если parsedData нет
        if (!hasParsedData && hasExercises)
          ..._buildDaysFromExercises(),
      ],
    );
  }

  List<Widget> _buildDaysFromParsedData() {
    final days = plan.parsedData!['days'] as List;
    final List<Widget> dayWidgets = [];

    for (var dayData in days) {
      final dayOfWeek = dayData['dayOfWeek'] as int;
      final rawLabel = dayData['dayLabel'] as String?;
      final dayLabel = (rawLabel != null && rawLabel.trim().isNotEmpty) ? rawLabel : 'День ${dayOfWeek + 1}';
      final description = dayData['description'] as String? ?? '';
      final items = dayData['items'] as List;

      dayWidgets.add(_buildParsedDayCard(dayOfWeek, dayLabel, description, items));
    }

    return dayWidgets;
  }

  Widget _buildParsedDayCard(int dayOfWeek, String dayLabel, String description, List<dynamic> items) {
    final dayName = dayLabel;

    // Подсчитываем общее количество упражнений в дне
    int totalExercises = 0;
    for (var item in items) {
      final exercises = item['exercises'] as List;
      totalExercises += exercises.length;
    }

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
                    '${dayOfWeek + 1}',
                    style: TextStyle(
                      color: AppColors.colorBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.colorWhite,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.colorGrey,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '$totalExercises упр.',
                  style: TextStyle(
                    color: AppColors.colorGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildParsedWorkoutItem(item, index);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedWorkoutItem(Map<String, dynamic> item, int index) {
    final type = item['type'] as String;
    final exercises = item['exercises'] as List;
    final restAfterGroup = item['restAfterGroup'];
    final rounds = item['rounds'];

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
                  color: _getItemTypeColor(type),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getItemTypeName(type),
                  style: const TextStyle(
                    color: AppColors.colorWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (rounds != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$rounds кругов',
                  style: const TextStyle(fontSize: 12, color: AppColors.colorWhite),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...exercises.map((exercise) => _buildParsedExerciseTile(exercise)).toList(),
          if (restAfterGroup != null) ...[
            const SizedBox(height: 8),
            Text(
              'Отдых после группы: $restAfterGroup сек',
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

  Widget _buildParsedExerciseTile(Map<String, dynamic> exercise) {
    final name = exercise['name'] as String? ?? 'Неизвестное упражнение';
    final note = exercise['note'] as String? ?? '';
    final reps = exercise['reps'];
    final workSets = exercise['workSets'] as int? ?? 0;
    final warmupSets = exercise['warmupSets'] as int? ?? 0;
    final restSeconds = exercise['restSeconds'] as int? ?? 0;

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
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.colorWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildSetInfo('Подходы', workSets.toString()),
                    if (reps != null) _buildSetInfo('Повторения', reps.toString()),
                    if (warmupSets > 0) _buildSetInfo('Разминка', warmupSets.toString()),
                    if (restSeconds > 0) _buildSetInfo('Отдых', '${restSeconds}с'),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
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

  List<Widget> _buildDaysFromExercises() {
    // Группируем упражнения по дням недели (старая логика)
    final exercisesByDay = <int, List<QuickPlanExercise>>{};
    for (final exercise in plan.exercises) {
      if (!exercisesByDay.containsKey(exercise.dayOfWeek)) {
        exercisesByDay[exercise.dayOfWeek] = [];
      }
      exercisesByDay[exercise.dayOfWeek]!.add(exercise);
    }

    // Сортируем по порядку упражнений в каждом дне
    for (final day in exercisesByDay.keys) {
      exercisesByDay[day]!.sort((a, b) => a.exerciseOrder.compareTo(b.exerciseOrder));
    }

    final sortedDays = exercisesByDay.keys.toList()..sort();

    return sortedDays.map((day) => _buildDayCard(day, exercisesByDay[day]!)).toList();
  }

  Widget _buildDayCard(int dayOfWeek, List<QuickPlanExercise> exercises) {
    final dayName = exercises.first.displayDayLabel;
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
                    '${dayOfWeek + 1}',
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
                Text(
                  '${exercises.length} упр.',
                  style: TextStyle(
                    color: AppColors.colorGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...exercises.map((exercise) => _buildExerciseTile(exercise)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(QuickPlanExercise exercise) {
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
                      exercise.customName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildSetInfo('Подходы', '${exercise.workSets}'),
                        _buildSetInfo('Повторения', '${exercise.reps}'),
                        if (exercise.warmupSets > 0)
                          _buildSetInfo('Разминка', '${exercise.warmupSets}'),
                        if (exercise.restSeconds > 0)
                          _buildSetInfo('Отдых', '${exercise.restSeconds}с'),
                      ],
                    ),
                    if (exercise.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Заметка: ${exercise.note}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.colorGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (exercise.description != null && exercise.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        exercise.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.colorGrey,
                        ),
                      ),
                    ],
                    if (exercise.instructions != null && exercise.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Инструкции:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.colorWhite,
                            ),
                          ),
                          ...exercise.instructions!.map((instruction) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• $instruction',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.colorGrey,
                              ),
                            ),
                          )).toList(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
            fontSize: 12,
            color: AppColors.colorGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
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
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.colorWhite,
              ),
              textAlign: TextAlign.right,
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

  int _getTotalExercisesCount() {
    // Считаем общее количество упражнений из parsedData или exercises
    if (plan.parsedData != null && plan.parsedData!['days'] != null) {
      int total = 0;
      final days = plan.parsedData!['days'] as List;
      for (var day in days) {
        final items = day['items'] as List;
        for (var item in items) {
          final exercises = item['exercises'] as List;
          total += exercises.length;
        }
      }
      return total;
    } else {
      return plan.exercises.length;
    }
  }

  Color _getItemTypeColor(String type) {
    switch (type) {
      case 'warmup':
        return Colors.blue.shade700;
      case 'single':
        return Colors.green.shade700;
      case 'superset':
        return AppColors.colorRed;
      case 'triset':
        return Colors.purple.shade700;
      case 'circuit':
        return AppColors.colorDarkRed;
      case 'cooldown':
        return Colors.teal.shade700;
      default:
        return AppColors.colorBlue;
    }
  }

  String _getItemTypeName(String type) {
    switch (type) {
      case 'warmup':
        return 'Разминка';
      case 'single':
        return 'Одиночное';
      case 'superset':
        return 'Суперсет';
      case 'triset':
        return 'Трисет';
      case 'circuit':
        return 'Круговое';
      case 'cooldown':
        return 'Заминка';
      default:
        return 'Упражнение';
    }
  }
}