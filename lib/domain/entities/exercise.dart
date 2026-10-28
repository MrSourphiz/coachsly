
enum WorkoutExecutionType {
  warmup,     // Разминка
  single,     // Одиночное упражнение
  superset,   // Суперсет
  triset,     // Трисет
  circuit,    // Круговая тренировка
  cooldown    // Заминка
}
class Exercise {
  final String id;
  final String title;
  final String description;
  final String category;
  final String bodyPart;
  final String equipment;
  final String difficultyLevel;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.bodyPart,
    required this.equipment,
    required this.difficultyLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'body_part': bodyPart,
      'difficulty_level': difficultyLevel,
      'equipment': equipment,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      bodyPart: json['body_part'] ?? '',
      equipment: json['equipment'] ?? '',
      difficultyLevel: json['difficulty_level'] ?? '',
    );
  }
}
