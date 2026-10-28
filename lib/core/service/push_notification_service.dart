import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/repositories/notifications_repository.dart';
import 'package:formeo/router.dart';

// Обработчик фоновых сообщений — должен быть top-level функцией
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase уже инициализирован — просто логируем
  debugPrint('Background message: ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Канал для Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'formeo_channel',
    'Formeo уведомления',
    description: 'Уведомления о тренировках и клиентах',
    importance: Importance.high,
  );

  Future<void> initialize(String trainerId) async {
    // 1. Настраиваем локальные уведомления
    await _setupLocalNotifications();

    // 2. Получаем и сохраняем токен ВСЕГДА, независимо от статуса разрешения.
    // Получение FCM-токена не требует разрешения на показ уведомлений —
    // это два независимых механизма. Если разрешение отклонено, устройство
    // всё равно получает пуши, просто ОС не покажет системный баннер
    // (у нас есть свой показ через flutter_local_notifications).
    await _saveToken(trainerId);

    // 3. Обновляем токен если он изменился
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveToken(trainerId, token: newToken);
    });

    // 4. Обработка уведомлений когда приложение открыто
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // 5. Обработка тапа на уведомление когда приложение в фоне
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _handleNotificationTap(message);
    });

    // 6. Проверяем уведомление которое открыло приложение
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationTap(initialMessage);
    }

    // 7. Запрашиваем системное разрешение ТОЛЬКО если его ещё не спрашивали
    // на этом устройстве. Если пользователь уже когда-то ответил
    // (разрешил/запретил) — повторный вызов requestPermission() всё равно
    // не покажет диалог, поэтому нет смысла его дёргать здесь снова.
    final currentSettings = await _messaging.getNotificationSettings();
    if (currentSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Текущий статус системного разрешения на уведомления.
  /// Используется в UI (например, экран настроек), чтобы показать
  /// пользователю реальное состояние и предложить перейти в настройки ОС,
  /// если разрешение было отклонено ранее.
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Включить пуши из UI приложения.
  /// Если разрешение ещё не запрашивалось — запрашивает.
  /// Если уже разрешено или уже отклонено (диалог ОС не переоткрыть) —
  /// просто (пере)сохраняет токен в БД, чтобы сервер начал/продолжил слать пуши.
  /// Возвращает актуальный статус разрешения, чтобы UI мог решить,
  /// нужно ли вести пользователя в системные настройки.
  Future<AuthorizationStatus> enableNotifications(String trainerId) async {
    var status = await getPermissionStatus();

    if (status == AuthorizationStatus.notDetermined) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      status = settings.authorizationStatus;
    }

    await _saveToken(trainerId);
    return status;
  }

  /// Отключить пуши из UI приложения.
  /// Мы не можем отозвать системное разрешение программно — это может
  /// сделать только сам пользователь в настройках ОС. Но мы можем удалить
  /// токен устройства из БД, чтобы сервер перестал слать этому устройству пуши.
  Future<void> disableNotifications(String trainerId) async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken != null) {
        await GetIt.instance<SupabaseDataSource>().deleteDeviceToken(
          trainerId: trainerId,
          token: fcmToken,
        );
        debugPrint('FCM токен удалён из БД: $fcmToken');
      }
    } catch (e) {
      debugPrint('Ошибка удаления токена: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    // Android
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // уже запрашиваем через Firebase
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      // ✅ Тап по foreground-уведомлению (показанному через
      // flutter_local_notifications, пока приложение открыто) — раньше
      // никак не обрабатывался. payload содержит закодированный
      // message.data, из которого достаём type/notification_id для навигации.
      onDidReceiveNotificationResponse: (details) async {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload));
          await _navigateForData(data);
        } catch (e) {
          debugPrint('Ошибка разбора payload уведомления: $e');
        }
      },
    );

    // Показываем уведомления на переднем плане на iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _saveToken(String trainerId, {String? token}) async {
    try {
      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('FCM токен не получен');
        return;
      }

      debugPrint('FCM токен: $fcmToken');

      final platform = Platform.isIOS ? 'ios' : 'android';

      await GetIt.instance<SupabaseDataSource>().saveDeviceToken(
        trainerId: trainerId,
        token: fcmToken,
        platform: platform,
      );

      debugPrint('FCM токен сохранён: $fcmToken');
    } catch (e) {
      debugPrint('Ошибка сохранения токена: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // ✅ Пробрасываем data пуша (в т.ч. type и notification_id), чтобы при
      // тапе на показанное foreground-уведомление можно было понять, куда вести.
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Уведомление нажато, тип: ${message.data['type']}');
    await _navigateForData(message.data);
  }

  /// Общая точка навигации для тапа по пушу — как из системного трея
  /// (фон/закрытое приложение, через onMessageOpenedApp/getInitialMessage),
  /// так и по локальному foreground-уведомлению.
  ///
  /// Если в data пуша есть notification_id — открываем карточку конкретного
  /// уведомления напрямую (NotificationDetailScreen). Если id отсутствует
  /// (например, для booking_confirmed/booking_canceled — по ним в
  /// приложении нет отдельной карточки в принципе) или запись не нашлась —
  /// ведём на общий список уведомлений.
  Future<void> _navigateForData(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    if (type == null) return;

    const knownTypes = {
      'retention_signal',
      'progress_report_sent',
      'new_client',
      'trainer_no_response',
      'receipt_uploaded',
      'booking_confirmed',
      'booking_canceled',
    };
    if (!knownTypes.contains(type)) return;

    final notificationId = data['notification_id'] as String?;

    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        final repo = GetIt.instance<NotificationsRepository>();
        final item = await repo.getNotificationById(notificationId);
        if (item != null) {
          if (!item.isRead) {
            await repo.markAsRead(item.id);
          }
          final context = rootNavigatorKey.currentContext;
          if (context == null) {
            debugPrint('Навигация по пушу пропущена: navigatorKey ещё не готов');
            return;
          }
          GoRouter.of(context).pushNamed('notificationDetail', extra: item);
          return;
        }
      } catch (e) {
        debugPrint('Не удалось загрузить уведомление $notificationId: $e');
      }
    }

    // Fallback — общий список уведомлений (id не пришёл, либо запись не нашлась)
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('Навигация по пушу пропущена: navigatorKey ещё не готов');
      return;
    }
    GoRouter.of(context).pushNamed('notifications');
  }
}
