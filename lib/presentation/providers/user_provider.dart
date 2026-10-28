import 'package:flutter/material.dart';
import 'package:formeo/domain/entities/user.dart';

class UserProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;

  void setUser(User user) {
    _user = user;
    debugPrint('UserProvider: setUser - ${user.email}, role: ${user.role}');
    notifyListeners();
  }

  /// Локально обновляет план подписки текущего пользователя
  /// (например после оплаты на закрытом пейволле), чтобы роутер
  /// сразу увидел hasAccess == true без перезагрузки сессии.
  void updateSubscriptionPlan(String plan) {
    if (_user == null) return;
    _user = _user!.copyWith(subscriptionPlan: plan);
    debugPrint('UserProvider: updateSubscriptionPlan - $plan');
    notifyListeners();
  }

  /// Оптимистично запускает триал локально (план='trial' + дата окончания
  /// через 14 дней), чтобы роутер не редиректил на /paywall до того как
  /// фоновый запрос startTrial успеет завершиться.
  void startTrialOptimistically() {
    if (_user == null) return;
    final now = DateTime.now();
    _user = _user!.copyWith(
      subscriptionPlan: 'trial',
      trialStartedAt: now,
      trialEndsAt: now.add(const Duration(days: 14)),
    );
    debugPrint('UserProvider: startTrialOptimistically');
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    debugPrint('UserProvider: clearUser');
    notifyListeners();
  }
}
