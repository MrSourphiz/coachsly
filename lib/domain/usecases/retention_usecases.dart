import 'package:formeo/domain/entities/retention_onboarding.dart';
import 'package:formeo/domain/entities/retention_checkin.dart';
import 'package:formeo/domain/entities/retention_signal.dart';
import 'package:formeo/domain/repositories/retention_repository.dart';

// ── Онбординг ──────────────────────────────────────────────────────────────

class SaveRetentionOnboarding {
  final RetentionRepository _repo;
  SaveRetentionOnboarding(this._repo);
  Future<void> execute(RetentionOnboarding onboarding) =>
      _repo.saveOnboarding(onboarding);
}

class GetRetentionOnboarding {
  final RetentionRepository _repo;
  GetRetentionOnboarding(this._repo);
  Future<RetentionOnboarding?> execute({
    required String clientId,
    required String trainerId,
  }) =>
      _repo.getOnboarding(clientId: clientId, trainerId: trainerId);
}

class CheckOnboardingCompleted {
  final RetentionRepository _repo;
  CheckOnboardingCompleted(this._repo);
  Future<bool> execute({
    required String clientId,
    required String trainerId,
  }) =>
      _repo.isOnboardingCompleted(clientId: clientId, trainerId: trainerId);
}

/// Запускает стартовый опрос удержания в Telegram у клиента,
/// если он ещё не проходил его. Вызывается при включении тоггла
/// "Механизм удержания" в карточке клиента.
class TriggerOnboardingStart {
  final RetentionRepository _repo;
  TriggerOnboardingStart(this._repo);
  Future<void> execute({
    required String clientId,
    required String trainerId,
    required int telegramUserId,
  }) =>
      _repo.triggerOnboardingStart(
        clientId: clientId,
        trainerId: trainerId,
        telegramUserId: telegramUserId,
      );
}

// ── Чек-ины ────────────────────────────────────────────────────────────────

class SaveRetentionCheckin {
  final RetentionRepository _repo;
  SaveRetentionCheckin(this._repo);
  Future<void> execute(RetentionCheckin checkin) =>
      _repo.saveCheckin(checkin);
}

class GetRetentionCheckins {
  final RetentionRepository _repo;
  GetRetentionCheckins(this._repo);
  Future<List<RetentionCheckin>> execute({
    required String clientId,
    int limit = 10,
  }) =>
      _repo.getCheckins(clientId: clientId, limit: limit);
}

class CheckCheckinDue {
  final RetentionRepository _repo;
  CheckCheckinDue(this._repo);
  Future<bool> execute(String clientId) => _repo.isCheckinDue(clientId);
}

// ── Сигналы ────────────────────────────────────────────────────────────────

class GetActiveRetentionSignals {
  final RetentionRepository _repo;
  GetActiveRetentionSignals(this._repo);
  Future<List<RetentionSignal>> execute(String trainerId) =>
      _repo.getActiveSignals(trainerId);
}

class ResolveRetentionSignal {
  final RetentionRepository _repo;
  ResolveRetentionSignal(this._repo);
  Future<void> execute(String signalId) => _repo.resolveSignal(signalId);
}

// ── Прогресс-срез ──────────────────────────────────────────────────────────

class GetClientProgressSummary {
  final RetentionRepository _repo;
  GetClientProgressSummary(this._repo);
  Future<Map<String, dynamic>> execute({
    required String clientId,
    required String trainerId,
    int periodDays = 28,
  }) =>
      _repo.getClientProgressSummary(
        clientId: clientId,
        trainerId: trainerId,
        periodDays: periodDays,
      );
}

class SetRetentionEnabled {
  final RetentionRepository _repo;
  SetRetentionEnabled(this._repo);
  Future<void> execute({required String clientId, required bool enabled}) =>
      _repo.setRetentionEnabled(clientId: clientId, enabled: enabled);
}

class GetRetentionEnabled {
  final RetentionRepository _repo;
  GetRetentionEnabled(this._repo);
  Future<bool> execute(String clientId) => _repo.getRetentionEnabled(clientId);
}
