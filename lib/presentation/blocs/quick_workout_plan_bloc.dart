// quick_workout_plan_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/usecases/get_quick_workout_plans.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';

// События
abstract class QuickWorkoutPlanEvent {}

class FetchQuickWorkoutPlans extends QuickWorkoutPlanEvent {
  final String userId;
  FetchQuickWorkoutPlans(this.userId);
}

class SubscribeQuickWorkoutPlans extends QuickWorkoutPlanEvent {
  final String trainerId;
  SubscribeQuickWorkoutPlans(this.trainerId);
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

  // Guard от двойного запуска подписки (resume, token refresh) —
  // тот же паттерн, что в ClientBloc/ScheduleBloc.
  bool _subscriptionActive = false;
  String? _subscribedTrainerId;

  QuickWorkoutPlanBloc({required this.getQuickWorkoutPlans}) : super(QuickWorkoutPlanInitial()) {
    on<FetchQuickWorkoutPlans>(_onFetchQuickWorkoutPlans);
    on<SubscribeQuickWorkoutPlans>(_onSubscribeQuickWorkoutPlans);
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

  Future<void> _onSubscribeQuickWorkoutPlans(
      SubscribeQuickWorkoutPlans event,
      Emitter<QuickWorkoutPlanState> emit,
      ) async {
    if (_subscriptionActive && _subscribedTrainerId == event.trainerId) {
      debugPrint(
          'SubscribeQuickWorkoutPlans: already active for ${event.trainerId}, skipping');
      return;
    }

    _subscriptionActive = true;
    _subscribedTrainerId = event.trainerId;

    if (state is! QuickWorkoutPlanSuccess) {
      emit(QuickWorkoutPlanLoading());
    }

    const maxRetries = 3;
    int attempt = 0;

    try {
      while (!emit.isDone) {
        try {
          await emit.forEach(
            GetIt.instance<SupabaseDataSource>()
                .subscribeQuickWorkoutPlans(event.trainerId),
            onData: (List<Map<String, dynamic>> rows) {
              final plans = rows.map((json) => QuickWorkoutPlan.fromJson(json)).toList();
              attempt = 0;
              debugPrint('SubscribeQuickWorkoutPlans update: ${plans.length}');
              return QuickWorkoutPlanSuccess(plans);
            },
            onError: (error, stackTrace) {
              debugPrint('SubscribeQuickWorkoutPlans stream error: $error');
              return state is QuickWorkoutPlanSuccess
                  ? state as QuickWorkoutPlanSuccess
                  : QuickWorkoutPlanLoading();
            },
          );
          break;
        } catch (e) {
          attempt++;
          debugPrint('SubscribeQuickWorkoutPlans catch attempt $attempt: $e');

          if (attempt >= maxRetries) {
            debugPrint('SubscribeQuickWorkoutPlans: max retries reached');
            if (!emit.isDone) {
              emit(QuickWorkoutPlanError('Ошибка подписки на планы: $e'));
            }
            return;
          }

          final delay = Duration(seconds: attempt * 2);
          debugPrint('SubscribeQuickWorkoutPlans: retry in ${delay.inSeconds}s');
          await Future.delayed(delay);

          if (!emit.isDone && state is! QuickWorkoutPlanSuccess) {
            emit(QuickWorkoutPlanLoading());
          }
        }
      }
    } finally {
      _subscriptionActive = false;
      debugPrint('SubscribeQuickWorkoutPlans: subscription ended, flag reset');
    }
  }
}
