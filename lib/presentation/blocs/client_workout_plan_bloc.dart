// application/bloc/client_workout_plan_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formeo/domain/entities/assigned_workout_plan.dart';
import 'package:formeo/domain/usecases/get_clients_workout_plans.dart';
import 'package:formeo/domain/usecases/assign_workout_plan.dart';
import 'package:formeo/domain/usecases/update_assigned_workout_plan.dart';
import 'package:formeo/domain/usecases/delete_assigned_workout_plan.dart';

// События
abstract class ClientWorkoutPlanEvent {}

class FetchClientWorkoutPlans extends ClientWorkoutPlanEvent {
  final String userId;
  FetchClientWorkoutPlans(this.userId);
}

class AssignWorkoutPlanEvent extends ClientWorkoutPlanEvent {
  final String trainerId;
  final String clientId;
  final String workoutProgramId;
  final DateTime startDate;
  final List<String> trainingDays;
  final int durationWeeks;
  final String type;

  AssignWorkoutPlanEvent({
    required this.trainerId,
    required this.clientId,
    required this.workoutProgramId,
    required this.startDate,
    required this.trainingDays,
    required this.durationWeeks,
    required this.type,
  });
}

class UpdateAssignedWorkoutPlanEvent extends ClientWorkoutPlanEvent {
  final AssignedWorkoutProgram plan;
  final String trainerId;
  UpdateAssignedWorkoutPlanEvent(this.plan, this.trainerId,);
}

class DeleteAssignedWorkoutPlanEvent extends ClientWorkoutPlanEvent {
  final String planId;
  final String trainerId;
  DeleteAssignedWorkoutPlanEvent(this.planId, this.trainerId,);
}

class GetWorkoutProgramInfoEvent extends ClientWorkoutPlanEvent {
  final String programId;
  GetWorkoutProgramInfoEvent(this.programId);
}

// Состояния
abstract class ClientWorkoutPlanState {}

class ClientWorkoutPlanInitial extends ClientWorkoutPlanState {}

class ClientWorkoutPlanLoading extends ClientWorkoutPlanState {}

class ClientWorkoutPlansLoaded extends ClientWorkoutPlanState {
  final List<AssignedWorkoutProgram> plans;
  ClientWorkoutPlansLoaded(this.plans);
}

class WorkoutProgramInfoLoaded extends ClientWorkoutPlanState {
  final Map<String, dynamic> programInfo;
  WorkoutProgramInfoLoaded(this.programInfo);
}

class ClientWorkoutPlanOperationSuccess extends ClientWorkoutPlanState {
  final String message;
  final List<AssignedWorkoutProgram>? plans;

  ClientWorkoutPlanOperationSuccess({
    this.message = 'Операция успешно выполнена',
    this.plans,
  });
}

class ClientWorkoutPlanError extends ClientWorkoutPlanState {
  final String message;
  ClientWorkoutPlanError(this.message);
}

// Bloc
class ClientWorkoutPlanBloc extends Bloc<ClientWorkoutPlanEvent, ClientWorkoutPlanState> {
  final GetClientsWorkoutPlans getClientsWorkoutPlans;
  final AssignWorkoutPlan assignWorkoutPlan;
  final UpdateAssignedWorkoutPlan updateAssignedWorkoutPlan;
  final DeleteAssignedWorkoutPlan deleteAssignedWorkoutPlan;

  ClientWorkoutPlanBloc({
    required this.getClientsWorkoutPlans,
    required this.assignWorkoutPlan,
    required this.updateAssignedWorkoutPlan,
    required this.deleteAssignedWorkoutPlan,
  }) : super(ClientWorkoutPlanInitial()) {
    on<FetchClientWorkoutPlans>(_onFetchClientWorkoutPlans);
    on<AssignWorkoutPlanEvent>(_onAssignWorkoutPlan);
    on<UpdateAssignedWorkoutPlanEvent>(_onUpdateAssignedWorkoutPlan);
    on<DeleteAssignedWorkoutPlanEvent>(_onDeleteAssignedWorkoutPlan);
  }

  Future<void> _onFetchClientWorkoutPlans(
      FetchClientWorkoutPlans event,
      Emitter<ClientWorkoutPlanState> emit,
      ) async {
    emit(ClientWorkoutPlanLoading());
    try {
      final plans = await getClientsWorkoutPlans.execute(event.userId);
      emit(ClientWorkoutPlansLoaded(plans));
    } catch (e) {
      emit(ClientWorkoutPlanError('Ошибка загрузки клиентских планов: $e'));
    }
  }

  Future<void> _onAssignWorkoutPlan(
      AssignWorkoutPlanEvent event,
      Emitter<ClientWorkoutPlanState> emit,
      ) async {
    emit(ClientWorkoutPlanLoading());
    try {
      // Создаем сущность плана
      final plan = AssignedWorkoutProgram(
        id: '', // Будет сгенерирован в базе
        trainerId: event.trainerId,
        clientId: event.clientId,
        workoutProgramId: event.workoutProgramId,
        startDate: event.startDate,
        trainingDays: event.trainingDays,
        durationWeeks: event.durationWeeks,
        createdAt: DateTime.now(),
        type: event.type,
      );

      // Назначаем план
      await assignWorkoutPlan.execute(plan);

      // После назначения обновляем список
      final plans = await getClientsWorkoutPlans.execute(event.trainerId);
      emit(ClientWorkoutPlanOperationSuccess(
        message: 'Тренировка успешно назначена',
        plans: plans,
      ));
    } catch (e) {
      emit(ClientWorkoutPlanError('Ошибка назначения тренировки: $e'));
    }
  }

  Future<void> _onUpdateAssignedWorkoutPlan(
      UpdateAssignedWorkoutPlanEvent event,
      Emitter<ClientWorkoutPlanState> emit,
      ) async {
    emit(ClientWorkoutPlanLoading());
    try {
      await updateAssignedWorkoutPlan.execute(event.plan);

      final plans = await getClientsWorkoutPlans.execute(event.trainerId);
      emit(ClientWorkoutPlanOperationSuccess(
        message: 'План успешно обновлен',
        plans: plans,
      ));
    } catch (e) {
      emit(ClientWorkoutPlanError('Ошибка обновления плана: $e'));
    }
  }

  Future<void> _onDeleteAssignedWorkoutPlan(
      DeleteAssignedWorkoutPlanEvent event,
      Emitter<ClientWorkoutPlanState> emit,
      ) async {
    emit(ClientWorkoutPlanLoading());
    try {
      await deleteAssignedWorkoutPlan.execute(event.planId);

      final plans = await getClientsWorkoutPlans.execute(event.trainerId);
      emit(ClientWorkoutPlanOperationSuccess(
        message: 'План успешно удален',
        plans: plans,
      ));
    } catch (e) {
      emit(ClientWorkoutPlanError('Ошибка удаления плана: $e'));
    }
  }

}
