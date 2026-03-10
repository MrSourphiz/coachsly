// quick_workout_plan_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/domain/usecases/get_quick_workout_plans.dart';


// События
abstract class QuickWorkoutPlanEvent {}

class FetchQuickWorkoutPlans extends QuickWorkoutPlanEvent {
  final String userId;
  FetchQuickWorkoutPlans(this.userId);
}

// Состояния
abstract class QuickWorkoutPlanState {}

class QuickWorkoutPlanInitial extends QuickWorkoutPlanState {}

class QuickWorkoutPlanLoading extends QuickWorkoutPlanState {}

class QuickWorkoutPlanSuccess extends QuickWorkoutPlanState {
  final List<QuickWorkoutPlan> quickWorkoutPlans;
  QuickWorkoutPlanSuccess(this.quickWorkoutPlans);
}

class QuickWorkoutPlanError extends QuickWorkoutPlanState {
  final String message;
  QuickWorkoutPlanError(this.message);
}

// Bloc
class QuickWorkoutPlanBloc extends Bloc<QuickWorkoutPlanEvent, QuickWorkoutPlanState> {
  final GetQuickWorkoutPlans getQuickWorkoutPlans;

  QuickWorkoutPlanBloc({required this.getQuickWorkoutPlans}) : super(QuickWorkoutPlanInitial()) {
    on<FetchQuickWorkoutPlans>(_onFetchQuickWorkoutPlans);
  }

  Future<void> _onFetchQuickWorkoutPlans(
      FetchQuickWorkoutPlans event,
      Emitter<QuickWorkoutPlanState> emit
      ) async {
    emit(QuickWorkoutPlanLoading());
    try {
      final quickWorkoutPlans = await getQuickWorkoutPlans.execute(event.userId);
      emit(QuickWorkoutPlanSuccess(quickWorkoutPlans));
    } catch (e) {
      emit(QuickWorkoutPlanError('Ошибка загрузки быстрых планов: $e'));
    }
  }
}