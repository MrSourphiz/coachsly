import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? token;
  final String role;
  final String timezone;
  final String? location;
  final bool retentionEnabled;
  final bool fatsecretNeeded;
  final String? subscriptionPlan;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final String subscriptionStatus;
  final DateTime? nextBillingAt;
  final bool autoRenew;

  User({
    required this.id,
    required this.email,
    this.token,
    required this.role,
    required this.timezone,
    this.location,
    this.retentionEnabled = false,
    this.fatsecretNeeded = false,
    this.subscriptionPlan,
    this.trialStartedAt,
    this.trialEndsAt,
    this.subscriptionStatus = 'trial',
    this.nextBillingAt,
    this.autoRenew = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['email'] == null ||
        json['role'] == null || json['timezone'] == null) {
      throw FormatException('Invalid JSON for User: $json');
    }
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      token: json['token'] as String?,
      role: json['role'] as String,
      timezone: json['timezone'] as String,
      location: json['location'] as String?,
      retentionEnabled: json['retention_enabled'] as bool? ?? false,
      fatsecretNeeded: json['fatsecret_needed'] as bool? ?? false,
      subscriptionPlan: json['subscription_plan'] as String?,
      trialStartedAt: json['trial_started_at'] != null
          ? DateTime.parse(json['trial_started_at'] as String)
          : null,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      subscriptionStatus: json['subscription_status'] as String? ?? 'trial',
      nextBillingAt: json['next_billing_at'] != null
          ? DateTime.parse(json['next_billing_at'] as String)
          : null,
      autoRenew: json['auto_renew'] as bool? ?? true,
    );
  }

  bool get isOnTrial {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  /// Pro-функции: оплаченный Pro или идущий пробный период.
  /// В триале доступно всё — на iOS тариф до конца триала не выбирается,
  /// иначе тренер не увидел бы вкладку «Тренировки» и прочие Pro-функции.
  bool get isPro =>
      isOnTrial || subscriptionPlan == 'pro' || subscriptionPlan == 'pro_yearly';

  bool get trialExpired {
    if (trialStartedAt == null) return false;
    if (trialEndsAt == null) return false;
    return DateTime.now().isAfter(trialEndsAt!);
  }

  /// Доступ даёт активный триал или оплаченная подписка —
  /// subscription_status='active' проставляет robokassa-result по вебхуку
  /// после успешной оплаты/автосписания через Robokassa.
  /// past_due — автосписание не прошло, идёт грейс-период
  /// (GRACE_PERIOD_DAYS в robokassa-recurring-charge), доступ сохраняется.
  bool get hasAccess =>
      isOnTrial ||
          subscriptionStatus == 'active' ||
          subscriptionStatus == 'past_due';

  User copyWith({
    String? timezone,
    String? location,
    bool? retentionEnabled,
    bool? fatsecretNeeded,
    String? subscriptionPlan,
    DateTime? trialStartedAt,
    DateTime? trialEndsAt,
    String? subscriptionStatus,
    DateTime? nextBillingAt,
    bool? autoRenew,
  }) {
    return User(
      id: id,
      email: email,
      token: token,
      role: role,
      timezone: timezone ?? this.timezone,
      location: location ?? this.location,
      retentionEnabled: retentionEnabled ?? this.retentionEnabled,
      fatsecretNeeded: fatsecretNeeded ?? this.fatsecretNeeded,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      nextBillingAt: nextBillingAt ?? this.nextBillingAt,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }

  @override
  List<Object?> get props => [
    id, email, token, role, timezone, location,
    retentionEnabled, fatsecretNeeded, subscriptionPlan, trialStartedAt, trialEndsAt,
    subscriptionStatus, nextBillingAt, autoRenew,
  ];
}