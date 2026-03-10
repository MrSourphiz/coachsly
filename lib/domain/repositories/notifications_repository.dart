import 'package:coachsly/domain/entities/notification.dart';

abstract class NotificationsRepository {
  Stream<List<NotificationItem>> subscribeNotifications(String trainerId);
  Future<void> markAsRead(String id);
}