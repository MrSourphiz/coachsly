import 'package:equatable/equatable.dart';
//import 'package:coachsly/domain/entities/exercise_model.dart';
import 'package:coachsly/domain/entities/exercise.dart';

enum WorkoutItemType {
  warmup,
  single,
  superset,
  triset,
  circuit,
  cooldown,
}

class WorkoutPlan extends Equatable {
  final String? id; // Генерируется Supabase, поэтому может быть null
  final String? name;
  final String? type;
  final int? duration;
  final List<WorkoutDay> days;
  final String? userId; // Может быть null если программа еще не назначена
  final String trainerId; // Обязательное поле
  final DateTime? createdAt; // Автоматически устанавливается Supabase

  const WorkoutPlan({
    this.id,
    this.name,
    this.type,
    this.duration,
    required this.days,
    this.userId,
    required this.trainerId,
    this.createdAt,
  });

  WorkoutPlan copyWith({
    String? id,
    String? name,
    String? type,
    int? duration,
    List<WorkoutDay>? days,
    String? userId,
    String? trainerId,
    DateTime? createdAt,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      days: days ?? this.days,
      userId: userId ?? this.userId,
      trainerId: trainerId ?? this.trainerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Для сохранения в таблицу workout_plans
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'duration': duration,
      'days': days.map((d) => d.toJson()).toList(),
      'user_id': userId,
      'trainer_id': trainerId,
      // created_at не включаем - генерируется на сервере
    };
  }

  // Для загрузки из таблицы workout_plans
  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as String?,
      name: json['name'] as String?,
      type: json['type'] as String?,
      duration: json['duration'] as int?,
      days: (json['days'] as List<dynamic>? ?? [])
          .map((d) => WorkoutDay.fromJson(d))
          .toList(),
      userId: json['user_id'] as String?,
      trainerId: json['trainer_id'] as String, // Обязательное поле
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  // Для создания из данных ИИ
  factory WorkoutPlan.fromAiResponse(Map<String, dynamic> json, String trainerId, {String? userId}) {
    return WorkoutPlan(
      name: json['name'] as String?,
      type: json['type'] as String?,
      duration: json['duration'] as int?,
      days: (json['days'] as List<dynamic>? ?? [])
          .map((day) => WorkoutDay.fromJson(day))
          .toList(),
      trainerId: trainerId,
      userId: userId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    duration,
    days,
    userId,
    trainerId,
    createdAt,
  ];
}

class WorkoutDay {
  final int dayOfWeek;
  final String description;
  final int restBetweenExercises;
  final List<WorkoutItem> items;

  WorkoutDay({
    required this.dayOfWeek,
    required this.description,
    required this.restBetweenExercises,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'description': description,
      'restBetweenExercises': restBetweenExercises,
    //  'items': items,
    'items': items.map((e) => e.toJson()).toList(),
    };
  }

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayOfWeek: json['dayOfWeek'],
      description: json['description'],
      restBetweenExercises: json['restBetweenExercises'],
    //  items: json['items'],
      items: (json['items'] as List)
          .map((e) => WorkoutItem.fromJson(e))
          .toList(),
    );
  }
}

class WorkoutItem {
  final WorkoutItemType type;
  final List<WorkoutExercise> exercises; // 1 для одиночного, >1 для групп
  final int? restBetweenExercises; // отдых внутри группы
  final int? restAfterGroup; // отдых после выполнения группы
  final int? rounds; // для круговых

  WorkoutItem({
    required this.type,
    required this.exercises,
    this.restBetweenExercises,
    this.restAfterGroup,
    this.rounds,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'restBetweenExercises': restBetweenExercises,
      'restAfterGroup': restAfterGroup,
      'rounds': rounds,
    };
  }

  factory WorkoutItem.fromJson(Map<String, dynamic> json) {
    return WorkoutItem(
      type: WorkoutItemType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
      ),
      exercises: (json['exercises'] as List)
          .map((e) => WorkoutExercise.fromJson(e))
          .toList(),
      restBetweenExercises: json['restBetweenExercises'],
      restAfterGroup: json['restAfterGroup'],
      rounds: json['rounds'],
    );
  }
}

class WorkoutExercise {
  final String id;
  final Exercise exercise;
  final String name;
  final String note;
  final int restSeconds;
  final int warmupSets;
  final int workSets;
  final int reps;

  WorkoutExercise({
    required this.id,
    required this.exercise,
    required this.note,
    required this.name,
    required this.restSeconds,
    required this.warmupSets,
    required this.workSets,
    required this.reps,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise': exercise.toJson(),
      'name': name,
      'note': note,
      'restSeconds': restSeconds,
      'warmupSets': warmupSets,
      'workSets': workSets,
      'reps': reps,
    };
  }

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'],
      exercise: Exercise.fromJson(json['exercise']),
      name: json['name'],
      note: json['note'],
      restSeconds: json['restSeconds'],
      warmupSets: json['warmupSets'],
      workSets: json['workSets'],
      reps: json['reps'],
    );
  }
}
