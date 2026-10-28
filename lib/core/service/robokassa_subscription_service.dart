// lib/core/service/robokassa_subscription_service.dart
//
// Тонкий клиент к edge function robokassa-create-payment.
// Открывает страницу оплаты Robokassa во внешнем/встроенном браузере.
// Подтверждение оплаты приходит на сервер (ResultURL) — приложение
// узнаёт об этом через уже существующий CheckAuthStatus/CheckAuth,
// который перечитывает users.subscription_status из БД.
//
// ⚠️ Только Android/web. На iOS оплаты в приложении нет (App Store 3.1.1).

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:formeo/core/constants/billing_config.dart';

class RobokassaSubscriptionService {
  final SupabaseClient _supabase;

  RobokassaSubscriptionService(this._supabase);

  /// plan: 'basic' | 'pro' | 'pro_yearly'
  /// Возвращает true, если браузер с оплатой успешно открыт.
  Future<bool> startSubscriptionPayment(String plan) async {
    // На iOS сюда попадать не должны — если дошли, это баг в UI.
    if (!BillingConfig.inAppPaymentsAllowed) {
      throw StateError('In-app payments are disabled on this platform');
    }

    final response = await _supabase.functions.invoke(
      'robokassa-create-payment',
      body: {'plan': plan},
    );

    if (response.status != 200 || response.data == null) {
      throw Exception('Не удалось создать платёж: ${response.data}');
    }

    final paymentUrl = response.data['payment_url'] as String?;
    if (paymentUrl == null) {
      throw Exception('Сервер не вернул ссылку на оплату');
    }

    final uri = Uri.parse(paymentUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}