import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/presentation/providers/user_provider.dart';

class CreateWorkoutPlanScreen extends StatefulWidget {
  const CreateWorkoutPlanScreen({super.key});

  @override
  State<CreateWorkoutPlanScreen> createState() => _CreateWorkoutPlanScreenState();
}

class _CreateWorkoutPlanScreenState extends State<CreateWorkoutPlanScreen> {
  final _nameController = TextEditingController();
  final _quickPlanController = TextEditingController();

  String _selectedType = '';

  String _selectedDuration = '';
  int? _manualWeeksInput;

  final Map<String, IconData> workoutTypes = {
    'Кардио': Icons.favorite,
    'Силовая': Icons.fitness_center,
    'Функциональная': Icons.directions_run,
    'Растяжка': Icons.accessibility_new,
    'Своя': Icons.create,
  };

  final durations = [
    '1 неделя',
    '2 недели',
    '4 недели',
    '6 недель',
    'Выбрать вручную',
  ];

  int get totalDays {
    switch (_selectedDuration) {
      case '1 неделя':
        return 7;
      case '2 недели':
        return 14;
      case '4 недели':
        return 28;
      case '6 недель':
        return 42;
      case 'Выбрать вручную':
        return (_manualWeeksInput ?? 0) * 7;
      default:
        return 14;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quickPlanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = GetIt.instance<UserProvider>();
    final user = userProvider.user;
    final double navBarHeight = 70.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    if (user == null) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: navBarHeight + bottomPadding + 70.0),
            child: Center(
              child: Text('Пользователь не авторизован', style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание плана'),
        backgroundColor: const Color(0xFF172554),
        foregroundColor: const Color(0xFFF9FAFB),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Возвращаем false при отмене создания
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: Container(
        color: const Color(0xFF172554),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickConstructor(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickConstructor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicParameters(),

        const SizedBox(height: 24),
        const Text(
          'Текст программы тренировки',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Вставьте полный протокол сразу по всем тренировочным дням — '
              'дни, упражнения, подходы и повторения приложение распознает из текста само',
          style: TextStyle(
            color: const Color(0xFFF9FAFB).withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _quickPlanController,
          maxLines: 10,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Просто вставьте сюда текст вашей программы тренировок...',
            alignLabelWithHint: true,
            hintStyle: TextStyle(color: Colors.black),
            filled: true,
            fillColor: Color(0xFFF9FAFB),
          ),
        ),

        const SizedBox(height: 32),
        Center(
          child: ElevatedButton(
            onPressed: _parseWorkoutPlanWithAI,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: const Color(0xFF7F1D1D),
              foregroundColor: const Color(0xFFF9FAFB),
            ),
            child: const Text(
              'Создать план из текста',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicParameters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Название тренировки',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Введите название, например: Силовая',
            hintStyle: TextStyle(color: Colors.black),
            filled: true,
            fillColor: Color(0xFFF9FAFB),
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Тип тренировки',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: workoutTypes.entries.map((entry) {
              final isSelected = _selectedType == entry.key;
              final type = entry.key;
              final icon = entry.value;
              return ChoiceChip(
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedType = type;
                  });
                },
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSelected)
                      Icon(icon, size: 18, color: const Color(0xFF7F1D1D)),
                    const SizedBox(width: 6),
                    Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFF9FAFB) : Colors.black,
                      ),
                    ),
                  ],
                ),
                selectedColor: const Color(0xFF7F1D1D),
                backgroundColor: const Color(0xFFF9FAFB),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Продолжительность программы тренировок',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8.0,
            children: durations.map((duration) {
              final isSelected = _selectedDuration == duration;
              return ChoiceChip(
                label: Text(
                  duration,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFF9FAFB) : Colors.black,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedDuration = duration;
                  });
                },
                selectedColor: const Color(0xFF7F1D1D),
                backgroundColor: const Color(0xFFF9FAFB),
              );
            }).toList(),
          ),
        ),
        if (_selectedDuration == 'Выбрать вручную') ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Введите количество недель',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF9FAFB),
              ),
              onChanged: (value) {
                setState(() {
                  _manualWeeksInput = int.tryParse(value) ?? 0;
                });
              },
            ),
          ),
        ],
      ],
    );
  }

  // ========== БЫСТРЫЙ КОНСТРУКТОР ==========

  Future<void> _parseWorkoutPlanWithAI() async {
    if (_quickPlanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст программы')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название тренировки')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a4066),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF9FAFB))),
              const SizedBox(height: 16),
              const Text(
                "Анализируем программу...",
                style: TextStyle(color: Color(0xFFF9FAFB)),
              ),
              const SizedBox(height: 8),
              Text(
                "Обрабатываем результаты",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFF9FAFB),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Индикатор должен закрываться ровно один раз, иначе второй pop
    // закроет сам экран или следующий диалог.
    var loadingOpen = true;
    void closeLoading() {
      if (loadingOpen && mounted) {
        loadingOpen = false;
        Navigator.pop(context);
      }
    }

    try {
      final userProvider = GetIt.instance<UserProvider>();
      final user = userProvider.user;
      if (user == null) throw Exception('Пользователь не авторизован');

      final supabase = GetIt.instance<SupabaseClient>();

      // Дни тренировок распознаются самой AI-функцией из текста программы —
      // отдельного графика/выбора дней тренер больше не заполняет,
      // протокол загружается сразу целиком по всем дням.
      final response = await supabase.functions.invoke('parse-workout-plan',
        body: {
          'workoutText': _quickPlanController.text,
          'planName': _nameController.text,
          'type': _selectedType,
          'duration': totalDays,
          'trainerId': user.id,
        },
      );

      closeLoading();
      if (!mounted) return;

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data['success'] == true) {
          final result = data['data'] as Map<String, dynamic>;
          final quickPlan = QuickWorkoutPlan.fromJson(result['quick_plan'] as Map<String, dynamic>);

          final exercises = await _loadQuickPlanExercises(quickPlan.id!);
          if (!mounted) return;
          final planWithExercises = quickPlan.copyWith(exercises: exercises);

          await _showQuickPlanPreview(planWithExercises);
          // После _showQuickPlanPreview произойдет возврат с результатом
        } else {
          throw Exception(data?['error']?.toString() ?? 'Неизвестная ошибка сервера');
        }
      } else {
        throw Exception('HTTP ${response.status}');
      }
    } catch (e) {
      closeLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при анализе программы: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<List<QuickPlanExercise>> _loadQuickPlanExercises(String planId) async {
    try {
      final supabase = GetIt.instance<SupabaseClient>();

      final response = await supabase
          .from('quick_plan_exercises')
          .select()
          .eq('quick_plan_id', planId);

      return response.map((e) => QuickPlanExercise.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Ошибка загрузки упражнений: $e');
      return [];
    }
  }

  Future<void> _showQuickPlanPreview(QuickWorkoutPlan initialPlan) async {
    // Актуальный план живёт здесь, а не в параметре: после генерации описаний
    // он заменяется на обновлённый, и диалог перерисовывается.
    var currentPlan = initialPlan;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final groupedExercises =
          _groupExercisesInOriginalOrder(currentPlan.exercises);

          return AlertDialog(
            backgroundColor: const Color(0xFF172554),
            title: const Text(
              'Быстрый план создан!',
              style: TextStyle(color: Color(0xFFF9FAFB)),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlanSummary(currentPlan, groupedExercises),

                  const SizedBox(height: 16),

                  if (currentPlan.exercises.any((e) => e.description == null))
                    _buildGenerateDescriptionsButton(
                      currentPlan,
                          (updated) => setDialogState(() => currentPlan = updated),
                    ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: _buildExercisesByDays(groupedExercises),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Проверьте распознанные данные перед назначением клиенту',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFF9FAFB),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(color: Color(0xFFF9FAFB)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2a4066),
                  foregroundColor: const Color(0xFFF9FAFB),
                ),
                child: const Text('Назначить клиенту'),
              ),
            ],
          );
        },
      ),
    );

    // План уже сохранён в БД к этому моменту (диалог показывается только
    // после успешного ответа parse-workout-plan) — независимо от того,
    // какую кнопку нажал тренер, возвращаемся на экран списка с true.
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Map<int, List<QuickPlanExercise>> _groupExercisesInOriginalOrder(List<QuickPlanExercise> exercises) {
    final grouped = <int, List<QuickPlanExercise>>{};

    for (final exercise in exercises) {
      if (!grouped.containsKey(exercise.dayOfWeek)) {
        grouped[exercise.dayOfWeek] = [];
      }
      grouped[exercise.dayOfWeek]!.add(exercise);
    }

    for (final day in grouped.keys) {
      grouped[day]!.sort((a, b) => a.exerciseOrder.compareTo(b.exerciseOrder));
    }

    final sortedKeys = grouped.keys.toList();
    sortedKeys.sort((a, b) {
      final minOrderA = grouped[a]!.map((e) => e.exerciseOrder).reduce((curr, next) => curr < next ? curr : next);
      final minOrderB = grouped[b]!.map((e) => e.exerciseOrder).reduce((curr, next) => curr < next ? curr : next);
      return minOrderA.compareTo(minOrderB);
    });

    final sortedMap = <int, List<QuickPlanExercise>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }

    return sortedMap;
  }

  Widget _buildPlanSummary(QuickWorkoutPlan plan, Map<int, List<QuickPlanExercise>> groupedExercises) {
    final totalExercises = plan.exercises.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Название: ${plan.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        Text(
          'Тип: ${plan.type}',
          style: const TextStyle(color: Color(0xFFF9FAFB)),
        ),
        Text(
          'Дней тренировок: ${groupedExercises.length}',
          style: const TextStyle(color: Color(0xFFF9FAFB)),
        ),
        Text(
          'Всего упражнений: $totalExercises',
          style: const TextStyle(color: Color(0xFFF9FAFB)),
        ),
      ],
    );
  }

  Widget _buildGenerateDescriptionsButton(
      QuickWorkoutPlan plan,
      void Function(QuickWorkoutPlan updated) onUpdated,
      ) {
    return ElevatedButton.icon(
      onPressed: () => _generateExerciseDescriptions(plan, onUpdated),
      icon: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFFF9FAFB)),
      label: const Text(
        "Сгенерировать описания упражнений",
        style: TextStyle(color: Color(0xFFF9FAFB)),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2a4066),
      ),
    );
  }

  Widget _buildExercisesByDays(Map<int, List<QuickPlanExercise>> groupedExercises) {
    final dayKeys = groupedExercises.keys.toList();

    return ListView.builder(
      shrinkWrap: true,
      itemCount: dayKeys.length,
      itemBuilder: (context, dayIndex) {
        final dayKey = dayKeys[dayIndex];
        final dayExercises = groupedExercises[dayKey]!;
        final dayName = dayExercises.first.displayDayLabel;

        return Card(
          color: const Color(0xFF172554),
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2a4066),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getDayColor(dayIndex),
                      radius: 16,
                      child: Text(
                        '${dayIndex + 1}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'День ${dayIndex + 1}: $dayName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFF9FAFB),
                        ),
                      ),
                    ),
                    Text(
                      '${dayExercises.length} ${_getExerciseWord(dayExercises.length)}',
                      style: const TextStyle(
                        color: Color(0xFFF9FAFB),
                      ),
                    ),
                  ],
                ),
              ),

              ...dayExercises.asMap().entries.map((entry) => _buildExerciseTile(entry.value, dayIndex, entry.key)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExerciseTile(QuickPlanExercise exercise, int dayIndex, int exerciseIndex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2a4066),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade600,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getDayColor(dayIndex).withValues(alpha: 0.2),
          radius: 20,
          child: Text(
            '${exerciseIndex + 1}',
            style: TextStyle(
              color: _getDayColor(dayIndex),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.customName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFFF9FAFB),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${exercise.workSets}×${exercise.reps}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF9FAFB),
                    ),
                  ),
                ),
                if (exercise.note.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF9FAFB),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        subtitle: exercise.description != null
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              exercise.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Color(0xFFF9FAFB),
              ),
            ),
          ],
        )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (exercise.description != null)
              const Icon(Icons.description, color: Colors.green, size: 20)
            else
              const Icon(Icons.description, color: Colors.grey, size: 20),
            if (exercise.restSeconds > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${exercise.restSeconds}с',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFF9FAFB),
                ),
              ),
            ],
          ],
        ),
        dense: true,
      ),
    );
  }

  Color _getDayColor(int dayIndex) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[dayIndex % colors.length];
  }

  String _getExerciseWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'упражнение';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'упражнения';
    return 'упражнений';
  }

  Future<void> _generateExerciseDescriptions(
      QuickWorkoutPlan plan,
      void Function(QuickWorkoutPlan updated) onUpdated,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a4066),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF9FAFB))),
            const SizedBox(height: 16),
            const Text(
              "Генерируем описания...",
              style: TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 8),
            Text(
              "Это может занять несколько минут",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFF9FAFB),
              ),
            ),
          ],
        ),
      ),
    );

    var loadingOpen = true;
    void closeLoading() {
      if (loadingOpen && mounted) {
        loadingOpen = false;
        Navigator.pop(context);
      }
    }

    try {
      final user = GetIt.instance<UserProvider>().user;
      if (user == null) throw Exception('Пользователь не авторизован');

      final supabase = GetIt.instance<SupabaseClient>();

      final exerciseNames = plan.exercises
          .where((e) => e.description == null)
          .map((e) => e.customName)
          .toList();

      debugPrint("Generating descriptions for: ${exerciseNames.join(', ')}");

      final response = await supabase.functions.invoke('generate-exercise-descriptions',
        body: {
          'exerciseNames': exerciseNames,
          'trainerId': user.id,
        },
      );

      closeLoading();
      if (!mounted) return;

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;

        if (data != null && data['success'] == true) {
          final results = (data['results'] as List<dynamic>).cast<Map<String, dynamic>>();

          final updatedExercises = plan.exercises.map((exercise) {
            final result = results.firstWhere(
                  (r) => r['exerciseName'] == exercise.customName,
              orElse: () => <String, dynamic>{},
            );

            if (result.isNotEmpty) {
              if (result['success'] == false) {
                debugPrint("Failed to generate description for ${exercise.customName}: ${result['error']}");
                return exercise;
              }

              return exercise.copyWith(
                description: result['description']?.toString(),
                instructions: result['instructions'] != null
                    ? List<String>.from(result['instructions'] as List)
                    : null,
              );
            }
            return exercise;
          }).toList();

          // Передаём обновлённый план в диалог превью — он перерисуется
          onUpdated(plan.copyWith(exercises: updatedExercises));

          final successful = results
              .where((r) => r['success'] != false && r['description'] != null)
              .length;
          final failed = results.length - successful;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Готово! Успешно: $successful, Не удалось: $failed"),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          throw Exception(data?['error']?.toString() ?? 'Неизвестная ошибка сервера');
        }
      } else {
        throw Exception('HTTP ${response.status}');
      }
    } catch (e) {
      closeLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка генерации описаний: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}