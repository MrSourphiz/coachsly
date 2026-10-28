import 'package:formeo/domain/entities/notification.dart';

abstract class NotificationsRepository {
  Stream<List<NotificationItem>> subscribeNotifications(String trainerId);
  Future<void> markAsRead(String id);

  /// Получить одно уведомление по id — используется для точной навигации
  /// по тапу на push-уведомление (см. PushNotificationService).
  Future<NotificationItem?> getNotificationById(String id);
}
