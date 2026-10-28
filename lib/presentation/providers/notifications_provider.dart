import 'dart:async';
import 'package:flutter/material.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/domain/repositories/notifications_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  final String trainerId;
  final NotificationsRepository _repository;

  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  StreamSubscription<List<NotificationItem>>? _sub;

  bool _isResubscribing = false;
  bool _disposed = false;

  NotificationsProvider({
    required this.trainerId,
    required NotificationsRepository repository,
  }) : _repository = repository {
    _subscribe();
  }

  void _subscribe() {
    _sub = _repository.subscribeNotifications(trainerId).listen(
          (data) {
        if (_disposed) return;
        _notifications = data;
        _isResubscribing = false;
        notifyListeners();
      },
      onError: (error) {
        if (_disposed) return;
        debugPrint('NotificationsProvider stream error: $error');

        // code 1000 = нормальное закрытие WebSocket (фон, обновление токена).
        // Переподключаемся автоматически — без этого после ухода в фон
        // уведомления перестают приходить до следующего ручного resubscribe().
        final isNormalClose = error.toString().contains('code: 1000') ||
            error.toString().contains('RealtimeCloseEvent(code: 1000');

        final delay = isNormalClose
            ? const Duration(milliseconds: 500)
            : const Duration(seconds: 3);

        Future.delayed(delay, () {
          if (!_disposed) resubscribe();
        });
      },
      cancelOnError: true,
    );
  }

  /// Переподключение при возврате из фона.
  /// Вызывается из SplashWrapper.didChangeAppLifecycleState.
  /// Не очищает _notifications — пользователь не видит пустой список.
  void resubscribe() {
    if (_isResubscribing) return;
    _isResubscribing = true;

    debugPrint('NotificationsProvider: resubscribing for $trainerId');
    _sub?.cancel();
    _subscribe();
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
