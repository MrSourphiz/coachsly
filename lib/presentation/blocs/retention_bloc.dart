import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formeo/domain/entities/retention_onboarding.dart';
import 'package:formeo/domain/entities/retention_checkin.dart';
import 'package:formeo/domain/entities/retention_signal.dart';
import 'package:formeo/domain/usecases/retention_usecases.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class RetentionEvent extends Equatable {
  const RetentionEvent();
  @override
  List<Object?> get props => [];
}

class LoadRetentionEnabledEvent extends RetentionEvent {
  final String clientId;
  const LoadRetentionEnabledEvent(this.clientId);
  @override
  List<Object?> get props => [clientId];
}

class SetRetentionEnabledEvent extends RetentionEvent {
  final String clientId;
  final String trainerId;
  final int telegramUserId;
  final bool enabled;
  const SetRetentionEnabledEvent({
    required this.clientId,
    required this.trainerId,
    required this.telegramUserId,
    required this.enabled,
  });
  @override
  List<Object?> get props => [clientId, trainerId, telegramUserId, enabled];
}

class CheckOnboardingEvent extends RetentionEvent {
  final String clientId;
  final String trainerId;
  const CheckOnboardingEvent({required this.clientId, required this.trainerId});
  @override
  List<Object?> get props => [clientId, trainerId];
}

class LoadOnboardingEvent extends RetentionEvent {
  final String clientId;
  final String trainerId;
  const LoadOnboardingEvent({required this.clientId, required this.trainerId});
  @override
  List<Object?> get props => [clientId, trainerId];
}

class SubmitOnboardingEvent extends RetentionEvent {
  final RetentionOnboarding onboarding;
  const SubmitOnboardingEvent(this.onboarding);
  @override
  List<Object?> get props => [onboarding];
}

class CheckCheckinDueEvent extends RetentionEvent {
  final String clientId;
  const CheckCheckinDueEvent(this.clientId);
  @override
  List<Object?> get props => [clientId];
}

class SubmitCheckinEvent extends RetentionEvent {
  final RetentionCheckin checkin;
  const SubmitCheckinEvent(this.checkin);
  @override
  List<Object?> get props => [checkin];
}

class LoadCheckinsEvent extends RetentionEvent {
  final String clientId;
  const LoadCheckinsEvent(this.clientId);
  @override
  List<Object?> get props => [clientId];
}

class LoadActiveSignalsEvent extends RetentionEvent {
  final String trainerId;
  const LoadActiveSignalsEvent(this.trainerId);
  @override
  List<Object?> get props => [trainerId];
}

class ResolveSignalEvent extends RetentionEvent {
  final String signalId;
  final String trainerId;
  const ResolveSignalEvent({required this.signalId, required this.trainerId});
  @override
  List<Object?> get props => [signalId, trainerId];
}

class LoadProgressSummaryEvent extends RetentionEvent {
  final String clientId;
  final String trainerId;
  const LoadProgressSummaryEvent({required this.clientId, required this.trainerId});
  @override
  List<Object?> get props => [clientId, trainerId];
}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════

abstract class RetentionState extends Equatable {
  const RetentionState();
  @override
  List<Object?> get props => [];
}

class RetentionEnabledLoaded extends RetentionState {
  final bool enabled;
  const RetentionEnabledLoaded(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class RetentionInitial extends RetentionState {}

class RetentionLoading extends RetentionState {}

class OnboardingNeeded extends RetentionState {}

class OnboardingAlreadyDone extends RetentionState {
  final RetentionOnboarding onboarding;
  const OnboardingAlreadyDone(this.onboarding);
  @override
  List<Object?> get props => [onboarding];
}

class OnboardingSubmitted extends RetentionState {}

class CheckinDue extends RetentionState {}

class CheckinNotDue extends RetentionState {}

class CheckinSubmitted extends RetentionState {}

class CheckinsLoaded extends RetentionState {
  final List<RetentionCheckin> checkins;
  const CheckinsLoaded(this.checkins);
  @override
  List<Object?> get props => [checkins];
}

class SignalsLoaded extends RetentionState {
  final List<RetentionSignal> signals;
  const SignalsLoaded(this.signals);
  @override
  List<Object?> get props => [signals];
}

class ProgressSummaryLoaded extends RetentionState {
  final Map<String, dynamic> summary;
  const ProgressSummaryLoaded(this.summary);
  @override
  List<Object?> get props => [summary];
}

/// Приглашение на онбординг отправлено (или клиент ещё не подключён к боту).
/// Не влияет на UI тоггла — используется, если понадобится показать снекбар.
class OnboardingTriggerResult extends RetentionState {
  final bool alreadyDone;
  const OnboardingTriggerResult(this.alreadyDone);
  @override
  List<Object?> get props => [alreadyDone];
}

class RetentionError extends RetentionState {
  final String message;
  const RetentionError(this.message);
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class RetentionBloc extends Bloc<RetentionEvent, RetentionState> {
  final CheckOnboardingCompleted _checkOnboarding;
  final GetRetentionOnboarding _getOnboarding;
  final SaveRetentionOnboarding _saveOnboarding;
  final CheckCheckinDue _checkCheckinDue;
  final SaveRetentionCheckin _saveCheckin;
  final GetRetentionCheckins _getCheckins;
  final GetActiveRetentionSignals _getSignals;
  final ResolveRetentionSignal _resolveSignal;
  final GetClientProgressSummary _getProgressSummary;
  final GetRetentionEnabled _getRetentionEnabled;
  final SetRetentionEnabled _setRetentionEnabled;
  final TriggerOnboardingStart _triggerOnboardingStart;

  RetentionBloc({
    required CheckOnboardingCompleted checkOnboarding,
    required GetRetentionOnboarding getOnboarding,
    required SaveRetentionOnboarding saveOnboarding,
    required CheckCheckinDue checkCheckinDue,
    required SaveRetentionCheckin saveCheckin,
    required GetRetentionCheckins getCheckins,
    required GetActiveRetentionSignals getSignals,
    required ResolveRetentionSignal resolveSignal,
    required GetClientProgressSummary getProgressSummary,
    required SetRetentionEnabled setRetentionEnabled,
    required GetRetentionEnabled getRetentionEnabled,
    required TriggerOnboardingStart triggerOnboardingStart,
  })  : _checkOnboarding = checkOnboarding,
        _getOnboarding = getOnboarding,
        _saveOnboarding = saveOnboarding,
        _checkCheckinDue = checkCheckinDue,
        _saveCheckin = saveCheckin,
        _getCheckins = getCheckins,
        _getSignals = getSignals,
        _resolveSignal = resolveSignal,
        _getProgressSummary = getProgressSummary,
        _getRetentionEnabled = getRetentionEnabled,
        _setRetentionEnabled = setRetentionEnabled,
        _triggerOnboardingStart = triggerOnboardingStart,
        super(RetentionInitial()) {
    on<CheckOnboardingEvent>(_onCheckOnboarding);
    on<LoadOnboardingEvent>(_onLoadOnboarding);
    on<SubmitOnboardingEvent>(_onSubmitOnboarding);
    on<CheckCheckinDueEvent>(_onCheckCheckinDue);
    on<SubmitCheckinEvent>(_onSubmitCheckin);
    on<LoadCheckinsEvent>(_onLoadCheckins);
    on<LoadActiveSignalsEvent>(_onLoadSignals);
    on<ResolveSignalEvent>(_onResolveSignal);
    on<LoadProgressSummaryEvent>(_onLoadProgressSummary);
    on<LoadRetentionEnabledEvent>(_onLoadRetentionEnabled);
    on<SetRetentionEnabledEvent>(_onSetRetentionEnabled);
  }

  Future<void> _onCheckOnboarding(
      CheckOnboardingEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      final done = await _checkOnboarding.execute(
        clientId: event.clientId,
        trainerId: event.trainerId,
      );

      emit(done ? OnboardingAlreadyDone(
        (await _getOnboarding.execute(
          clientId: event.clientId,
          trainerId: event.trainerId,
        ))!,
      ) : OnboardingNeeded());
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onLoadRetentionEnabled(
      LoadRetentionEnabledEvent event,
      Emitter<RetentionState> emit,
      ) async {
    try {
      final enabled = await _getRetentionEnabled.execute(event.clientId);
      emit(RetentionEnabledLoaded(enabled));
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onSetRetentionEnabled(
      SetRetentionEnabledEvent event,
      Emitter<RetentionState> emit,
      ) async {
    try {
      await _setRetentionEnabled.execute(
        clientId: event.clientId,
        enabled: event.enabled,
      );
      emit(RetentionEnabledLoaded(event.enabled));

      // Активируем механизм только при включении и если данных ещё нет —
      // ошибки триггера не должны откатывать включённый тоггл, поэтому
      // ловим их отдельно и не эмитим RetentionError поверх успешного enable.
      if (event.enabled) {
        try {
          final done = await _checkOnboarding.execute(
            clientId: event.clientId,
            trainerId: event.trainerId,
          );
          if (!done) {
            await _triggerOnboardingStart.execute(
              clientId: event.clientId,
              trainerId: event.trainerId,
              telegramUserId: event.telegramUserId,
            );
          }
        } catch (_) {
          // Тоггл уже включён и сохранён — сбой отправки приглашения
          // не должен ломать основной флоу. Молча игнорируем здесь;
          // при необходимости можно завести отдельное состояние для снекбара.
        }
      }
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onLoadOnboarding(
      LoadOnboardingEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      final onboarding = await _getOnboarding.execute(
        clientId: event.clientId,
        trainerId: event.trainerId,
      );
      if (onboarding != null) {
        emit(OnboardingAlreadyDone(onboarding));
      } else {
        emit(OnboardingNeeded());
      }
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onSubmitOnboarding(
      SubmitOnboardingEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      await _saveOnboarding.execute(event.onboarding);
      emit(OnboardingSubmitted());
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onCheckCheckinDue(
      CheckCheckinDueEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      final due = await _checkCheckinDue.execute(event.clientId);
      emit(due ? CheckinDue() : CheckinNotDue());
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onSubmitCheckin(
      SubmitCheckinEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      await _saveCheckin.execute(event.checkin);
      emit(CheckinSubmitted());
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onLoadCheckins(
      LoadCheckinsEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      final checkins = await _getCheckins.execute(clientId: event.clientId);
      emit(CheckinsLoaded(checkins));
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onLoadSignals(
      LoadActiveSignalsEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      final signals = await _getSignals.execute(event.trainerId);
      emit(SignalsLoaded(signals));
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onResolveSignal(
      ResolveSignalEvent event,
      Emitter<RetentionState> emit,
      ) async {
    try {
      await _resolveSignal.execute(event.signalId);
      // Перезагружаем список сигналов
      final signals = await _getSignals.execute(event.trainerId);
      emit(SignalsLoaded(signals));
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }

  Future<void> _onLoadProgressSummary(
      LoadProgressSummaryEvent event,
      Emitter<RetentionState> emit,
      ) async {
    emit(RetentionLoading());
    try {
      final summary = await _getProgressSummary.execute(
        clientId: event.clientId,
        trainerId: event.trainerId,
      );
      emit(ProgressSummaryLoaded(summary));
    } catch (e) {
      emit(RetentionError(e.toString()));
    }
  }
}
