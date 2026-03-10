class Exercise {
  final String id;
  final String name;
  final String type;
  final String description;
  final List<String> mainMuscles;
  final String difficultyLevel;
  final List<String> equipment;

  Exercise({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.mainMuscles,
    required this.difficultyLevel,
    required this.equipment,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'main_muscles': mainMuscles,
      'difficulty_level': difficultyLevel,
      'equipment': equipment,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      mainMuscles: List<String>.from(json['main_muscles'] ?? []),
      difficultyLevel: json['difficulty_level'] ?? '',
      equipment: List<String>.from(json['equipment'] ?? []),
    );
  }
}
