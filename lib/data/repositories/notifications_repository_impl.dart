import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final SupabaseDataSource _dataSource;

  NotificationsRepositoryImpl(this._dataSource);

  @override
  Stream<List<NotificationItem>> subscribeNotifications(String trainerId) {
    final response = _dataSource.subscribeNotifications(trainerId);

    return response;
  }

  @override
  Future<void> markAsRead(String id)  {
    final response = _dataSource.markAsRead(id);
    return response;
  }

  @override
  Future<NotificationItem?> getNotificationById(String id) {
    return _dataSource.getNotificationById(id);
  }
}
