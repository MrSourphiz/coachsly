import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/domain/entities/exercise.dart';
import 'package:coachsly/presentation/screens/exercise_detail_screen.dart';
import 'package:coachsly/presentation/blocs/exercises_bloc.dart';
import 'package:coachsly/core/service/service_locator.dart';

class ExercisePickerScreen extends StatefulWidget {
  final WorkoutExecutionType executionType;
  final int maxExercises;

  const ExercisePickerScreen({
    super.key,
    required this.executionType,
    this.maxExercises = 1,
  });

  static Widget create({
    required WorkoutExecutionType executionType,
    int maxExercises = 1,
  }) {
    return BlocProvider(
      create: (context) => serviceLocator<ExercisePickerBloc>(),
      child: ExercisePickerScreen(
        executionType: executionType,
        maxExercises: maxExercises,
      ),
    );
  }

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final List<String> categories = [
    'Strength', 'Plyometrics', 'Cardio', 'Stretching',
    'Powerlifting', 'Strongman', 'Olympic Weightlifting'
  ];

  final List<String> muscleGroups = [
    'Abdominals', 'Adductors', 'Abductors', 'Biceps', 'Calves',
    'Chest', 'Forearms', 'Glutes', 'Hamstrings', 'Lats', 'Lower Back',
    'Middle Back', 'Traps', 'Neck', 'Quadriceps', 'Shoulders', 'Triceps'
  ];

  final List<String> equipment = [
    'Bands', 'Barbell', 'Kettlebells', 'Dumbbell', 'Other',
    'Cable', 'Machine', 'Body Only', 'Medicine Ball', 'Bodyweight',
    'Exercise Ball', 'Foam Roll', 'E-Z Curl Bar'
  ];

  final List<String> difficultyLevels = ['Beginner', 'Intermediate', 'Expert'];

  final Set<String> selectedCategories = {};
  final Set<String> selectedMuscles = {};
  final Set<String> selectedEquipment = {};
  final Set<String> selectedDifficulties = {};

  final List<Exercise> _selectedExercises = [];
  Timer? _debounceTimer;

  // Состояние раскрытия каждой секции
  final Map<String, bool> _sectionExpansionState = {
    'muscleGroups': true,
    'categories': true,
    'equipment': true,
    'difficulty': true,
  };

  // Оптимизация: кэш для виджетов карточек
  final Map<String, Widget> _exerciseCardCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExercisePickerBloc>().add(ResetFiltersEvent());
    });
  }

  void _emitFilters() {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      final hasSelectedFilters = selectedCategories.isNotEmpty ||
          selectedMuscles.isNotEmpty ||
          selectedEquipment.isNotEmpty ||
          selectedDifficulties.isNotEmpty;

      if (hasSelectedFilters) {
        context.read<ExercisePickerBloc>().add(
          UpdateFiltersEvent(
            categories: selectedCategories.toList(),
            muscles: selectedMuscles.toList(),
            equipment: selectedEquipment.toList(),
            difficulty: selectedDifficulties.toList(),
          ),
        );
      } else {
        context.read<ExercisePickerBloc>().add(ResetFiltersEvent());
      }
    });
  }

  void _onExerciseSelected(Exercise exercise) {
    setState(() {
      final existingIndex = _selectedExercises.indexWhere((e) => e.id == exercise.id);

      if (existingIndex != -1) {
        _selectedExercises.removeAt(existingIndex);
      } else {
        switch (widget.executionType) {
          case WorkoutExecutionType.warmup:
          case WorkoutExecutionType.single:
          case WorkoutExecutionType.cooldown:
            _selectedExercises.clear();
            _selectedExercises.add(exercise);
            break;

          case WorkoutExecutionType.superset:
            if (_selectedExercises.length < 2) {
              _selectedExercises.add(exercise);
            } else {
              _selectedExercises.removeLast();
              _selectedExercises.add(exercise);
            }
            break;

          case WorkoutExecutionType.triset:
            if (_selectedExercises.length < 3) {
              _selectedExercises.add(exercise);
            } else {
              _selectedExercises.removeLast();
              _selectedExercises.add(exercise);
            }
            break;

          case WorkoutExecutionType.circuit:
            if (_selectedExercises.length < widget.maxExercises) {
              _selectedExercises.add(exercise);
            } else {
              _selectedExercises.removeLast();
              _selectedExercises.add(exercise);
            }
            break;
        }
      }

      // Очищаем кэш при изменении выбора
      _exerciseCardCache.clear();
    });
  }

  String _getSaveButtonText() {
    final count = _selectedExercises.length;
    final max = _getMaxExercises();

    if (count == 0) return 'Выберите упражнения';
    if (count == max) return 'Сохранить ($count/$max)';
    return 'Сохранить ($count/$max)';
  }

  int _getMaxExercises() {
    switch (widget.executionType) {
      case WorkoutExecutionType.warmup:
      case WorkoutExecutionType.single:
      case WorkoutExecutionType.cooldown:
        return 1;
      case WorkoutExecutionType.superset:
        return 2;
      case WorkoutExecutionType.triset:
        return 3;
      case WorkoutExecutionType.circuit:
        return widget.maxExercises;
    }
  }

  // Версия фильтров с ExpansionTile и адаптивной высотой
  Widget _buildFilterSection(String title, List<String> options, Set<String> selectedSet, String sectionKey) {
    final isExpanded = _sectionExpansionState[sectionKey] ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок секции
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _sectionExpansionState[sectionKey] = !isExpanded;
              });
            },
          ),
          // Содержимое секции (показывается только если раскрыта)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((option) {
                  final selected = selectedSet.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          selectedSet.add(option);
                        } else {
                          selectedSet.remove(option);
                        }
                      });
                      _emitFilters();
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Оптимизированная версия карточки с кэшированием
  Widget _buildExerciseCard(Exercise exercise, bool isSelected) {
    final cacheKey = '${exercise.id}_$isSelected';

    if (_exerciseCardCache.containsKey(cacheKey)) {
      return _exerciseCardCache[cacheKey]!;
    }

    final card = _ExerciseCard(
      key: ValueKey(cacheKey),
      exercise: exercise,
      isSelected: isSelected,
      onTap: () => _onExerciseSelected(exercise),
      onDetailTap: () => _showExerciseDetails(exercise),
    );

    _exerciseCardCache[cacheKey] = card;
    return card;
  }

  void _showExerciseDetails(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.grey),
            title: Container(
              width: double.infinity,
              height: 16,
              color: Colors.grey,
            ),
            subtitle: Container(
              width: 100,
              height: 12,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  // Оптимизированный список с правильной прокруткой
  Widget _buildExerciseList(List<Exercise> exercises) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index];
        final isSelected = _selectedExercises.any((e) => e.id == ex.id);
        return _buildExerciseCard(ex, isSelected);
      },
    );
  }

  Widget _buildSelectedExercisesInfo() {
    if (_selectedExercises.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выбрано упражнений: ${_selectedExercises.length}/${_getMaxExercises()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ..._selectedExercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;
            return Text(
              '${index + 1}. ${exercise.title}',
              style: const TextStyle(fontSize: 12),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _exerciseCardCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор упражнения'),
        actions: [
          if (_selectedExercises.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedExercises.clear();
                  _exerciseCardCache.clear();
                });
              },
              child: const Text(
                'Отменить',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Блок фильтров - занимает столько места, сколько нужно
          Material(
            elevation: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterSection('Мышечные группы', muscleGroups, selectedMuscles, 'muscleGroups'),
                _buildFilterSection('Категории', categories, selectedCategories, 'categories'),
                _buildFilterSection('Экипировка', equipment, selectedEquipment, 'equipment'),
                _buildFilterSection('Уровень сложности', difficultyLevels, selectedDifficulties, 'difficulty'),
              ],
            ),
          ),

          const Divider(thickness: 1, height: 0),

          // Информация о выбранных упражнениях
          _buildSelectedExercisesInfo(),

          // Основной контент с упражнениями - занимает всё оставшееся пространство
          Expanded(
            child: BlocBuilder<ExercisePickerBloc, ExercisePickerState>(
              builder: (context, state) {
                if (state is ExercisePickerInitial) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Выберите фильтры для поиска упражнений',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                if (state is ExercisePickerLoading && state.exercises.isEmpty) {
                  return _buildSkeletonLoading();
                }

                if (state is ExercisePickerLoading && state.exercises.isNotEmpty) {
                  return Column(
                    children: [
                      Expanded(child: _buildExerciseList(state.exercises)),
                      const LinearProgressIndicator(),
                    ],
                  );
                }

                if (state is ExercisePickerError) {
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Ошибка: ${state.error}',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (state.exercises.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Показаны ранее загруженные упражнения:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: _buildExerciseList(state.exercises),
                        ),
                      ]
                    ],
                  );
                }

                if (state is ExercisePickerLoaded) {
                  if (state.exercises.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Нет упражнений по выбранным фильтрам'),
                      ),
                    );
                  } else {
                    return _buildExerciseList(state.exercises);
                  }
                }

                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),

          // Кнопка сохранения
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedExercises.isNotEmpty
                        ? () {
                      Navigator.pop(context, _selectedExercises);
                    }
                        : null,
                    child: Text(_getSaveButtonText()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetailTap;

  const _ExerciseCard({
    required this.exercise,
    required this.isSelected,
    required this.onTap,
    required this.onDetailTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
      shape: isSelected
          ? RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      )
          : null,
      child: ListTile(
        dense: true,
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          exercise.title ?? 'Без названия',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${exercise.bodyPart ?? ''} | ${exercise.difficultyLevel ?? ''}',
          style: const TextStyle(fontSize: 12),
        ),
        onTap: onTap,
        trailing: IconButton(
          icon: const Icon(Icons.info_outline, size: 20),
          onPressed: onDetailTap,
        ),
      ),
    );
  }
}