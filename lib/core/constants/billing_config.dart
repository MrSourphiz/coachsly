import 'package:flutter/foundation.dart';

/// Где можно показывать оплату подписки Formeo внутри приложения.
///
/// iOS/macOS: оплаты в приложении нет вообще — ни цен, ни тарифов, ни ссылок
/// на сайт (правило App Store 3.1.1). Подписка оформляется в веб-кабинете,
/// о нём тренер узнаёт из писем, а не из приложения.
/// Android и web: остаётся текущий пейволл с Robokassa.
class BillingConfig {
  BillingConfig._();

  static bool get inAppPaymentsAllowed {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS;
  }

  /// Веб-кабинет. Ссылку показываем ТОЛЬКО там, где inAppPaymentsAllowed == true.
  static const cabinetUrl = 'https://myformeo.ru/account/';

  static const supportEmail = 'support@myformeo.ru';
}