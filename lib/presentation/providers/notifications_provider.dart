import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coachsly/domain/entities/notification.dart';
import 'package:coachsly/domain/repositories/notifications_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  final String trainerId;
  final NotificationsRepository _repository;

  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  StreamSubscription<List<NotificationItem>>? _sub;

  NotificationsProvider({
    required this.trainerId,
    required NotificationsRepository repository,
  }) : _repository = repository {
    _subscribe();
  }

  void _subscribe() {
    _sub = _repository.subscribeNotifications(trainerId).listen((data) {
      _notifications = data;
      notifyListeners();
    });
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
