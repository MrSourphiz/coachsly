import 'package:formeo/domain/entities/client.dart';

abstract class ClientRepository {
  /// Получает список клиентов для указанного тренера.
  Future<List<Client>> fetchClients(String trainerId);

  /// Добавляет нового клиента для указанного тренера.
  Future<void> addNewClient(String trainerId, String name, String phoneNumber, {String? notes});

  /// Генерирует ссылку-приглашение для клиента.
  Future<String> createInvitation(String trainerId);

  /// Удаляет ссылку-приглашение из таблицы.
  Future<void> deleteInvitation(String token);

  /// Регистрирует клиента по указанному токену.
  Future<void> registerClientWithToken(String token, String name, String phoneNumber);

  /// Обновляет статус клиента.
  Future<void> updateClientStatus(String clientId, String status);

  /// Удаляет клиента.
  Future<void> deleteClient(String clientId);

  Future<void> updateClientSessionType(String clientId, String sessionType);
  Future<List<Map<String, dynamic>>> getClientBookings(String clientId);
  Future<List<Map<String, dynamic>>> getClientPayments(String clientId);
  Future<Map<String, dynamic>?> getClientActiveBlock(String clientId);
  Future<Map<String, dynamic>?> getClientActiveSubscription(String clientId);
  Future<Map<String, dynamic>?> getBookingById(String bookingId);
  Future<List<Map<String, dynamic>>> getClientAllBlocks(String clientId);
  Future<List<Map<String, dynamic>>> getClientAllSubscriptions(String clientId);
  Future<void> updateClientNotes(String clientId, String notes);
  Stream<List<Client>> subscribeClients(String trainerId);
  Future<List<Map<String, dynamic>>> getClientNutritionWeekly(String clientId);

  /// Загружает настройки оплаты тренера (block_sessions, subscription_days и др.)
  Future<Map<String, dynamic>?> getTrainerPaymentDetails(String trainerId);

  /// Загружает все данные для первого экрана карточки клиента одним запросом.
  /// Возвращает: next_booking, stats, has_scheduled, active_block, active_subscription.
  Future<Map<String, dynamic>> getClientDashboard(String clientId);

  /// Сбрасывает кэш dashboard для конкретного клиента.
  /// Вызывать после создания блока, абонемента, смены типа тренировки.
  void invalidateDashboardCache(String clientId);

  /// Создаёт активный блок тренировок для клиента.
  Future<void> createBlock({
    required String trainerId,
    required String clientId,
    required int totalSessions,
  });

  /// Создаёт активный абонемент для клиента.
  Future<void> createSubscription({
    required String trainerId,
    required String clientId,
    required int days,
  });

  /// Возвращает текущее состояние fatsecret_enabled для клиента.
  Future<bool> getFatsecretEnabled(String clientId);

  /// Включает или отключает интеграцию FatSecret для конкретного клиента.
  Future<void> setFatsecretEnabled({
    required String clientId,
    required bool enabled,
  });

  /// Отправляет клиенту в Telegram приглашение подключить FatSecret,
  /// если он ещё не подключён. Вызывать при включении тоггла (false -> true).
  Future<FatsecretPromptResult> triggerFatsecretConnectPrompt({
    required String clientId,
    required String trainerId,
  });
}

/// Результат попытки отправить клиенту приглашение подключить FatSecret.
class FatsecretPromptResult {
  final bool alreadyConnected;
  final bool sent;
  final String? error;

  const FatsecretPromptResult({
    required this.alreadyConnected,
    required this.sent,
    this.error,
  });
}
