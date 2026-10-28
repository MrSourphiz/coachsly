import 'package:formeo/domain/entities/retention_onboarding.dart';
import 'package:formeo/domain/entities/retention_checkin.dart';
import 'package:formeo/domain/entities/retention_signal.dart';

abstract class RetentionRepository {
  // ── Онбординг ──────────────────────────────────────────────────────────────

  /// Сохраняет стартовый опрос клиента.
  Future<void> saveOnboarding(RetentionOnboarding onboarding);

  /// Возвращает онбординг клиента, если он уже прошёл опрос.
  Future<RetentionOnboarding?> getOnboarding({
    required String clientId,
    required String trainerId,
  });

  /// Проверяет, прошёл ли клиент стартовый опрос.
  Future<bool> isOnboardingCompleted({
    required String clientId,
    required String trainerId,
  });

  /// Запускает стартовый опрос удержания у клиента в Telegram,
  /// вызывая edge-функцию retention-bot (type: start_onboarding).
  /// Вызывать только если isOnboardingCompleted == false.
  Future<void> triggerOnboardingStart({
    required String clientId,
    required String trainerId,
    required int telegramUserId,
  });

  // ── Чек-ины ────────────────────────────────────────────────────────────────

  /// Сохраняет чек-ин самочувствия клиента.
  Future<void> saveCheckin(RetentionCheckin checkin);

  /// Возвращает все чек-ины клиента, отсортированные по дате (новые первые).
  Future<List<RetentionCheckin>> getCheckins({
    required String clientId,
    int limit = 10,
  });

  /// Возвращает последний чек-ин клиента.
  Future<RetentionCheckin?> getLastCheckin(String clientId);

  /// Проверяет, нужен ли клиенту чек-ин (прошло >= 14 дней с последнего).
  Future<bool> isCheckinDue(String clientId);

  // ── Сигналы ────────────────────────────────────────────────────────────────

  /// Создаёт сигнал тренеру (красный / жёлтый).
  Future<void> createSignal({
    required String clientId,
    required String trainerId,
    required String signalLevel,
    required String reason,
  });

  /// Возвращает активные (нерезолвленные) сигналы для тренера.
  Future<List<RetentionSignal>> getActiveSignals(String trainerId);

  /// Отмечает сигнал как решённый.
  Future<void> resolveSignal(String signalId);

  // ── Аналитика для прогресс-среза ───────────────────────────────────────────

  /// Возвращает сводку клиента: тренировки, динамика оценок.
  /// Используется для прогресс-среза раз в 4 недели.
  Future<Map<String, dynamic>> getClientProgressSummary({
    required String clientId,
    required String trainerId,
    int periodDays = 28,
  });

  /// Включает или отключает механизм удержания для клиента.
  /// Вызывается тренером из карточки клиента.
  Future<void> setRetentionEnabled({
    required String clientId,
    required bool enabled,
  });

  /// Возвращает текущее состояние флага retention_enabled.
  Future<bool> getRetentionEnabled(String clientId);
}
