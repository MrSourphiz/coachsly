// lib/domain/entities/quick_workout_plan_model.dart
import 'package:equatable/equatable.dart';

class QuickWorkoutPlan extends Equatable {
  final String? id;
  final String name;
  final String? type;
  final int? duration;
  final String? schedule;
  final List<String>? selectedDays;
  final String? originalText;
  final Map<String, dynamic>? parsedData;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<QuickPlanExercise> exercises;

  const QuickWorkoutPlan({
    this.id,
    required this.name,
    this.type,
    this.duration,
    this.schedule,
    this.selectedDays,
    this.originalText,
    this.parsedData,
    this.status = 'draft',
    this.createdAt,
    this.updatedAt,
    this.exercises = const [],
  });

  factory QuickWorkoutPlan.fromJson(Map<String, dynamic> json) {
    return QuickWorkoutPlan(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      duration: json['duration'],
      schedule: json['schedule'],
      selectedDays: (json['selected_days'] as List<dynamic>?)?.cast<String>(),
      originalText: json['original_text'],
      parsedData: json['parsed_data'],
      status: json['status'] ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => QuickPlanExercise.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'duration': duration,
      'schedule': schedule,
      'selected_days': selectedDays,
      'original_text': originalText,
      'parsed_data': parsedData,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  QuickWorkoutPlan copyWith({
    String? id,
    String? name,
    String? type,
    int? duration,
    String? schedule,
    List<String>? selectedDays,
    String? originalText,
    Map<String, dynamic>? parsedData,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuickPlanExercise>? exercises,
  }) {
    return QuickWorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      schedule: schedule ?? this.schedule,
      selectedDays: selectedDays ?? this.selectedDays,
      originalText: originalText ?? this.originalText,
      parsedData: parsedData ?? this.parsedData,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      exercises: exercises ?? this.exercises,
    );
  }

  @override
  List<Object?> get props => [
    id, name, type, duration, schedule, selectedDays,
    originalText, parsedData, status, createdAt, updatedAt, exercises
  ];

  static const Map<String, String> _typeLabels = {
    'cardio': 'Кардио',
    'strength': 'Силовая',
    'functional': 'Функциональная',
    'stretching': 'Растяжка',
    'custom': 'Своя',
    'general': 'Общая',
  };

  /// Тип плана по-русски для отображения в UI. type может прийти уже
  /// по-русски (ручное создание через ChoiceChip в
  /// create_workout_plan_screen.dart) или по-английски (AI-парсер
  /// программы из текста). Незнакомые/уже русские значения возвращаются
  /// как есть — тот же приём, что и в displayDayLabel у QuickPlanExercise.
  String get typeLabel {
    final t = type;
    if (t == null || t.isEmpty) return 'Без типа';
    return _typeLabels[t.toLowerCase()] ?? t;
  }
}

class QuickPlanExercise extends Equatable {
  final String? id;
  final String quickPlanId;
  final String? trainerExerciseId;
  final String customName;
  final int dayOfWeek;
  final String? dayLabel;
  final int exerciseOrder;
  final String note;
  final int reps;
  final int workSets;
  final int warmupSets;
  final int restSeconds;
  final DateTime? createdAt;
  final String? description;
  final List<String>? instructions;

  const QuickPlanExercise({
    this.id,
    required this.quickPlanId,
    this.trainerExerciseId,
    required this.customName,
    required this.dayOfWeek,
    this.dayLabel,
    required this.exerciseOrder,
    required this.note,
    required this.reps,
    required this.workSets,
    this.warmupSets = 0,
    required this.restSeconds,
    this.createdAt,
    this.description,
    this.instructions,
  });

  /// Название дня для отображения — используется всюду, где раньше был
  /// жёстко вычисленный день недели (Пн/Вт/Ср...). Если тренер грузил
  /// программу до появления day_label (либо AI вернула пустую метку) —
  /// показываем нейтральное "День N" вместо неверного дня недели.
  String get displayDayLabel {
    final label = dayLabel;
    if (label != null && label.trim().isNotEmpty) return label;
    return 'День ${dayOfWeek + 1}';
  }

  factory QuickPlanExercise.fromJson(Map<String, dynamic> json) {
    return QuickPlanExercise(
      id: json['id'],
      quickPlanId: json['quick_plan_id'],
      trainerExerciseId: json['trainer_exercise_id'],
      customName: json['custom_name'],
      dayOfWeek: json['day_of_week'],
      dayLabel: json['day_label'] as String?,
      exerciseOrder: json['exercise_order'],
      note: json['note'] ?? '',
      reps: json['reps'],
      workSets: json['work_sets'],
      warmupSets: json['warmup_sets'] ?? 0,
      restSeconds: json['rest_seconds'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      description: json['description'],
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'quick_plan_id': quickPlanId,
      'trainer_exercise_id': trainerExerciseId,
      'custom_name': customName,
      'day_of_week': dayOfWeek,
      'day_label': dayLabel,
      'exercise_order': exerciseOrder,
      'note': note,
      'reps': reps,
      'work_sets': workSets,
      'warmup_sets': warmupSets,
      'rest_seconds': restSeconds,
      'created_at': createdAt?.toIso8601String(),
      'description': description,
      'instructions': instructions,
    };
  }

  QuickPlanExercise copyWith({
    String? id,
    String? quickPlanId,
    String? trainerExerciseId,
    String? customName,
    int? dayOfWeek,
    String? dayLabel,
    int? exerciseOrder,
    String? note,
    int? reps,
    int? workSets,
    int? warmupSets,
    int? restSeconds,
    DateTime? createdAt,
    String? description,
    List<String>? instructions,
  }) {
    return QuickPlanExercise(
      id: id ?? this.id,
      quickPlanId: quickPlanId ?? this.quickPlanId,
      trainerExerciseId: trainerExerciseId ?? this.trainerExerciseId,
      customName: customName ?? this.customName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayLabel: dayLabel ?? this.dayLabel,
      exerciseOrder: exerciseOrder ?? this.exerciseOrder,
      note: note ?? this.note,
      reps: reps ?? this.reps,
      workSets: workSets ?? this.workSets,
      warmupSets: warmupSets ?? this.warmupSets,
      restSeconds: restSeconds ?? this.restSeconds,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
    );
  }

  @override
  List<Object?> get props => [
    id, quickPlanId, trainerExerciseId, customName, dayOfWeek, dayLabel,
    exerciseOrder, note, reps, workSets, warmupSets, restSeconds,
    createdAt, description, instructions
  ];
}