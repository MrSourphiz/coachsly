import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/usecases/get_workout_plans.dart';
import 'package:formeo/domain/usecases/create_workout_plan.dart';

abstract class WorkoutPlanEvent {}

class FetchWorkoutPlans extends WorkoutPlanEvent {
  final String userId;
  FetchWorkoutPlans(this.userId);
}

class AddWorkoutPlan extends WorkoutPlanEvent {
  final String userId;
  final WorkoutPlan workoutPlan;
  AddWorkoutPlan(this.userId, this.workoutPlan);
}

abstract class WorkoutPlanState {}

class WorkoutPlanInitial extends WorkoutPlanState {}

class WorkoutPlanLoading extends WorkoutPlanState {}

class WorkoutPlanCreated extends WorkoutPlanState {}

class WorkoutPlanSuccess extends WorkoutPlanState {
  final List<WorkoutPlan> workoutPlans;
  WorkoutPlanSuccess(this.workoutPlans);
}

class WorkoutPlanError extends WorkoutPlanState {
  final String message;
  WorkoutPlanError(this.message);
}

class WorkoutPlanBloc extends Bloc<WorkoutPlanEvent, WorkoutPlanState> {
  final GetWorkoutPlans getWorkoutPlans;
  final CreateWorkoutPlan createWorkoutPlan;

  WorkoutPlanBloc({
    required this.getWorkoutPlans,
    required this.createWorkoutPlan,
  }) : super(WorkoutPlanInitial()) {
    on<FetchWorkoutPlans>(_onFetchWorkoutPlans);
    on<AddWorkoutPlan>(_onAddWorkoutPlan);
  }

  Future<void> _onFetchWorkoutPlans(FetchWorkoutPlans event, Emitter<WorkoutPlanState> emit) async {
    emit(WorkoutPlanLoading());
    try {
      final workoutPlans = await getWorkoutPlans.execute(event.userId);

      debugPrint('ВОТ ЛОГ 2: $workoutPlans');
      emit(WorkoutPlanSuccess(workoutPlans));
    } catch (e) {
      // Детальное логирование ошибки
      debugPrint('❌ WorkoutPlanBloc: Ошибка типа: ${e.runtimeType}');
      debugPrint('❌ WorkoutPlanBloc: Сообщение: ${e.toString()}');

      // Если это DataException, попробуем получить внутреннюю ошибку
      if (e is DataException) {
        debugPrint('❌ WorkoutPlanBloc: Это DataException, детали:');
        debugPrint('❌ WorkoutPlanBloc: ${e.toString()}');
      }

      // Также выведем stack trace для отладки
      debugPrint('📋 WorkoutPlanBloc: StackTrace: ${e.toString()}');
      emit(WorkoutPlanError('Ошибка загрузки планов тренировок: $e'));
    }
  }

  Future<void> _onAddWorkoutPlan(AddWorkoutPlan event, Emitter<WorkoutPlanState> emit) async {
    emit(WorkoutPlanLoading());
    try {
      await createWorkoutPlan.execute(
          CreateWorkoutPlanParams(event.userId, event.workoutPlan)
      );
      //final workoutPlans = await getWorkoutPlans.execute(event.userId);
      emit(WorkoutPlanCreated());
    } catch (e) {
      emit(WorkoutPlanError('Ошибка добавления плана тренировок: $e'));
    }
  }
}
