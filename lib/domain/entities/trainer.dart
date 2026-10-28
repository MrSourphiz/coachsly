import 'package:equatable/equatable.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';

class Trainer extends Equatable {
  final String id;
  final String name;
  final List<WorkoutPlan> workoutPlans;

  Trainer({
    required this.id,
    required this.name,
    required this.workoutPlans,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'workoutPlans': workoutPlans.map((plan) => plan.toJson()).toList(),
  };

  static Trainer fromJson(Map<String, dynamic> json) => Trainer(
    id: json['id'] as String,
    name: json['name'] as String,
    workoutPlans: (json['workoutPlans'] as List<dynamic>)
        .map((planJson) => WorkoutPlan.fromJson(planJson as Map<String, dynamic>))
        .toList(),
  );

  @override
  List<Object?> get props => [id, name, workoutPlans];
}
