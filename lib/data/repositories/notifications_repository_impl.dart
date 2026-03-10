import 'package:coachsly/data/sources/supabase_data_source.dart';
import 'package:coachsly/domain/entities/notification.dart';
import 'package:coachsly/domain/repositories/notifications_repository.dart';

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
}