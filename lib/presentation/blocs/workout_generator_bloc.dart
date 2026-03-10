import 'package:bloc/bloc.dart';
import 'package:coachsly/core/errors/failures.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/usecases/generate_workout_plan.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

part 'workout_generator_event.dart';
part 'workout_generator_state.dart';

class WorkoutGeneratorBloc extends Bloc<WorkoutGeneratorEvent, WorkoutGeneratorState> {
  final GenerateWorkoutPlan generateWorkoutPlan;

  WorkoutGeneratorBloc({required this.generateWorkoutPlan}) : super(WorkoutGeneratorInitial()) {
    on<GenerateWorkoutPlanEvent>(_onGenerateWorkoutPlan);
  }

  Future<void> _onGenerateWorkoutPlan(
      GenerateWorkoutPlanEvent event,
      Emitter<WorkoutGeneratorState> emit,
  ) async {
    emit(WorkoutGeneratorLoading());

    try {
      final plan = await generateWorkoutPlan.execute(
        GenerateWorkoutPlanParams(
          userData: event.userData,
          programParams: event.programParams,
          accessToken: event.accessToken,
        ),
      );
      emit(WorkoutGeneratorSuccess(plan));
    } catch (e) {
      emit(WorkoutGeneratorFailure(e.toString()));
    }
  }
}