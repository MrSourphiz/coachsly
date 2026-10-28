import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/core/service/robokassa_subscription_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:provider/provider.dart';
import 'package:formeo/presentation/providers/notifications_provider.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/router.dart' show setOnboardingCompleted;
import 'package:formeo/core/constants/billing_config.dart';
// show обязателен: AuthState из auth_bloc конфликтует с AuthState из supabase_flutter.
import 'package:formeo/presentation/blocs/auth_bloc.dart' show AuthBloc, SignOut;
import 'package:formeo/ui/widgets/ios_access_screens.dart';

// ── Ссылки на юридические документы — актуализировать под реальный домен ──
const _ofertaUrl = 'https://myformeo.ru/oferta.html';
const _privacyUrl = 'https://myformeo.ru/privacy-policy.html';
const _consentText =
    'Я согласен на автоматические списания согласно условиям оферты. Я ознакомлен(а) и согласен(на) с условиями оферты и политикой конфиденциальности';

// ─────────────────────────────────────────────────────────────
//  PaywallScreen
//
//  Показывается после онбординга.
//  Оплатил → сохраняем plan → /main
//  Закрыл крестиком → startTrial → /main
//
//  Также показывается когда trial_ends_at истёк.
//
//  ⚠️ План и даты триала (trial_started_at / trial_ends_at) всегда
//  сохраняются ОДНИМ атомарным запросом (ds.saveSubscriptionAndStartTrial),
//  а не двумя последовательными (saveSubscription + startTrial).
//  Это принципиально: main_screen.dart через 3 сек. после захода на /main
//  шлёт CheckAuthStatusEvent, который перечитывает пользователя из БД и
//  перезаписывает оптимистичный локальный стейт. Если бы план и триал
//  писались раздельно, между двумя запросами возможно промежуточное
//  состояние в БД (subscription_plan уже есть, а trial_ends_at ещё null),
//  которое CheckAuthStatusEvent мог бы подхватить — и тогда
//  user.hasAccess == false при user.subscriptionPlan != null → пейволл
//  ошибочно показывался бы в закрытом (_locked) виде сразу после онбординга,
//  хотя 14-дневный триал только что начался.
//
//  ⚠️ Оплата после истечения триала (_locked == true) ведёт на реальную
//  оплату через Robokassa (RobokassaSubscriptionService), а не продлевает
//  триал заново. Подтверждение приходит на сервер асинхронно (webhook
//  robokassa-result), поэтому после возврата из браузера мы перечитываем
//  пользователя через CheckAuth — см. didChangeAppLifecycleState ниже.
//
//  ⚠️ Чекбокс согласия с офертой ОБЯЗАТЕЛЕН для обеих кнопок (и старта
//  триала, и прямой оплаты) — кнопка неактивна, пока _consentGiven == false.
//  При нажатии факт согласия пишется в subscription_consents (требование
//  Robokassa для рекуррентных платежей — история согласий пользователей).
//
//  ⚠️ iOS (BillingConfig.inAppPaymentsAllowed == false): тарифов, цен и
//  оплаты здесь нет вообще (правило App Store 3.1.1). Вместо пейволла —
//  IosAccessIntro (старт триала) или IosAccessInactive (доступ истёк).
//  Оплата — только в веб-кабинете; после неё экран сам перечитывает
//  users и открывает приложение (таймер + возврат в приложение).
// ─────────────────────────────────────────────────────────────

enum _BillingMode { monthly, yearly }

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with WidgetsBindingObserver {
  _BillingMode _mode = _BillingMode.monthly;
  // monthly: 'basic' | 'pro'   yearly: 'pro_yearly'
  String _selectedPlan = 'pro';
  bool _loading = false;

  // Если тренер включил retention или FatSecret в онбординге —
  // показываем только Pro (Basic скрыт как нерелевантный).
  bool _proOnly = false;

  // true, если триал/подписка истекли и тренер попал сюда не из онбординга —
  // пейволл нельзя закрыть, крестик скрыт.
  bool _locked = false;

  // true между открытием браузера с оплатой Robokassa и возвратом в приложение —
  // используется, чтобы понять, нужно ли при возврате перечитывать пользователя.
  bool _awaitingPayment = false;

  // true, если пользователь отметил чекбокс согласия с офертой —
  // без него кнопка неактивна (и для триала, и для оплаты).
  bool _consentGiven = false;

  // iOS: пока открыт экран «Доступ неактивен», раз в 15 сек. проверяем,
  // не оплатил ли тренер подписку на сайте.
  Timer? _pollTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = GetIt.instance<UserProvider>().user;
    // Доступ истёк: триал уже был (или выбран план), а доступа нет.
    // trialStartedAt проверяем отдельно — иначе тренер с планом null
    // попадал бы на «старт триала», который сервер уже не даст повторить.
    if (user != null &&
        !user.hasAccess &&
        (user.subscriptionPlan != null || user.trialStartedAt != null)) {
      // Показываем закрытый пейволл, вариант зависит от того,
      // что тренер выбрал изначально.
      _locked = true;
      _proOnly =
          user.subscriptionPlan == 'pro' || user.subscriptionPlan == 'pro_yearly';
      if (_proOnly) _selectedPlan = 'pro';
      if (!BillingConfig.inAppPaymentsAllowed) {
        _pollTimer = Timer.periodic(
          const Duration(seconds: 15),
              (_) => _refreshAccess(silent: true),
        );
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map && extra['proOnly'] == true) {
        setState(() => _proOnly = true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ловим возврат пользователя в приложение.
  // Подтверждение платежа приходит на сервер асинхронно (webhook
  // robokassa-result), поэтому просто перечитываем пользователя из БД —
  // без диплинков и кастомных URL-схем.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_awaitingPayment) {
      // Android: вернулись из браузера после оплаты Robokassa.
      _awaitingPayment = false;
      _refreshAccess(silent: false);
    } else if (_locked) {
      // iOS (и Android): тренер мог оплатить в веб-кабинете,
      // пока приложение было свёрнуто.
      _refreshAccess(silent: true);
    }
  }

  /// Перечитывает users из БД. Если доступ появился (вебхук robokassa-result
  /// уже проставил subscription_status = 'active') — уходим в приложение.
  Future<void> _refreshAccess({required bool silent}) async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);
    try {
      final currentUser = GetIt.instance<UserProvider>().user;
      if (currentUser == null) return;
      final row = await GetIt.instance<SupabaseClient>()
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .single();
      final freshUser = User.fromJson(row);
      debugPrint(
          'Paywall: fresh subscription_status=${freshUser.subscriptionStatus} hasAccess=${freshUser.hasAccess}');
      GetIt.instance<UserProvider>().setUser(freshUser);
      if (!mounted) return;
      if (freshUser.hasAccess) {
        _pollTimer?.cancel();
        context.go('/main');
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(BillingConfig.inAppPaymentsAllowed
              ? 'Платёж пока не подтверждён. Если оплата прошла — обновите через минуту.'
              : 'Доступ пока не восстановлен.'),
        ));
      }
    } catch (e) {
      debugPrint('Paywall: refresh access failed: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _subscribe() async {
    if (!_consentGiven) return; // подстраховка — кнопка и так неактивна
    setState(() => _loading = true);
    final user = GetIt.instance<UserProvider>().user!;
    final plan = _mode == _BillingMode.yearly ? 'pro_yearly' : _selectedPlan;
    final ds = GetIt.instance<SupabaseDataSource>();

    // Записываем согласие с офертой при каждом оформлении (и триала, и
    // прямой оплаты) — исторический факт для Robokassa и для собственной
    // подстраховки на случай спора.
    try {
      await GetIt.instance<SupabaseClient>().from('subscription_consents').insert({
        'user_id': user.id,
        'plan': plan,
        'consent_text': _consentText,
        'oferta_url': _ofertaUrl,
      });
    } catch (e) {
      debugPrint('Paywall: не удалось записать согласие: $e');
      // Не блокируем пользователя из-за сбоя записи лога — но логируем,
      // чтобы можно было расследовать постфактум.
    }

    if (_locked) {
      // Триал истёк — ведём на реальную оплату через Robokassa.
      // InvId и Shp_user=<user_id> генерирует edge function
      // robokassa-create-payment, активацию подписки делает вебхук
      // robokassa-result по факту оплаты — здесь мы ничего не пишем в БД сами.
      try {
        final ok = await GetIt.instance<RobokassaSubscriptionService>()
            .startSubscriptionPayment(plan);
        if (!ok) throw Exception('Не удалось открыть страницу оплаты');
        if (mounted) {
          setState(() => _loading = false);
          _awaitingPayment = true;
        }
      } catch (e) {
        debugPrint('Paywall: robokassa payment failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Ошибка оплаты: $e')));
          setState(() => _loading = false);
        }
      }
      return;
    }

    // Если пользователь ушёл с экрана, пока ждали ответ сервера — context не валиден
    if (!mounted) return;

    // Захватываем провайдер сейчас, пока context валиден —
    // после навигации этот экран будет размонтирован
    final notificationsProvider = context.read<NotificationsProvider?>();

    GetIt.instance<ScheduleBloc>().add(SubscribeSchedules(user.id));
    setOnboardingCompleted(true);
    // Оптимистично обновляем план ДО навигации — иначе роутер увидит
    // user.hasAccess == false (subscriptionPlan ещё null) и редиректит
    // обратно на /paywall как "доступ истёк".
    // Оптимистично запускаем триал И обновляем план ДО навигации.
    // Роутер проверяет hasAccess = isOnTrial — нужны обе операции.
    GetIt.instance<UserProvider>().startTrialOptimistically();
    GetIt.instance<UserProvider>().updateSubscriptionPlan(plan);
    if (mounted) context.go('/main');

    // Сохраняем подписку, запускаем триал и создаём демо-клиента в фоне —
    // не блокируем переход в приложение.
    // ВАЖНО: план и даты триала пишутся ОДНИМ атомарным запросом (см. комментарий
    // выше в _subscribe) — это устраняет гонку с CheckAuthStatusEvent
    // из main_screen.dart, из-за которой пейволл мог залочиться сразу после онбординга.
    unawaited(() async {
      try {
        await ds.saveSubscriptionAndStartTrial(user.id, plan);
      } catch (e) {
        debugPrint('Paywall: saveSubscriptionAndStartTrial failed: $e');
      }
      try {
        await ds.createDemoClient(user.id);
      } catch (e) {
        debugPrint('Paywall: createDemoClient failed: $e');
      }
      // Пересоздаём подписки ПОСЛЕ createDemoClient — иначе гонка.
      await Future.delayed(const Duration(milliseconds: 500));
      final clientBloc = GetIt.instance<ClientBloc>();
      clientBloc.add(ResubscribeClients(user.id));
      GetIt.instance<ScheduleBloc>().add(ResubscribeSchedules(user.id));
      notificationsProvider?.resubscribe();
      Future.delayed(const Duration(seconds: 2), () {
        clientBloc.add(FetchClients(user.id));
        GetIt.instance<ScheduleBloc>().add(ResubscribeSchedules(user.id));
      });
    }());
  }

  Future<void> _startTrial() async {
    final user = GetIt.instance<UserProvider>().user!;
    final ds = GetIt.instance<SupabaseDataSource>();
    final notificationsProvider = context.read<NotificationsProvider?>();

    GetIt.instance<ScheduleBloc>().add(SubscribeSchedules(user.id));
    setOnboardingCompleted(true);
    // Оптимистично запускаем триал ДО навигации — иначе роутер увидит
    // user.hasAccess == false и редиректит обратно на /paywall.
    GetIt.instance<UserProvider>().startTrialOptimistically();
    if (mounted) context.go('/main');

    // Сохраняем триал в фоне — не блокируем переход.
    // ВАЖНО: план и даты триала пишутся ОДНИМ атомарным запросом — устраняет
    // гонку с CheckAuthStatusEvent из main_screen.dart (см. комментарий в _subscribe).
    unawaited(() async {
      try {
        await ds.saveSubscriptionAndStartTrial(user.id, 'trial');
      } catch (e) {
        debugPrint('Paywall: saveSubscriptionAndStartTrial failed: $e');
      }
      try {
        await ds.createDemoClient(user.id);
      } catch (e) {
        debugPrint('Paywall: createDemoClient failed: $e');
      }
      // Пересоздаём подписки, чтобы подхватить демо-клиента, его расписание и уведомления
      final clientBloc = GetIt.instance<ClientBloc>();
      clientBloc.add(ResubscribeClients(user.id));
      // Доп. разовый fetch как fallback — на случай если realtime-подписка
      // ещё не успела вернуть initial данные
      Future.delayed(const Duration(seconds: 2), () {
        clientBloc.add(FetchClients(user.id));
      });
      GetIt.instance<ScheduleBloc>().add(ResubscribeSchedules(user.id));
      notificationsProvider?.resubscribe();
    }());
  }

  @override
  Widget build(BuildContext context) {
    // iOS: никаких тарифов и оплаты — только старт триала / нейтральный экран.
    if (!BillingConfig.inAppPaymentsAllowed) {
      return _locked
          ? IosAccessInactive(
        refreshing: _refreshing,
        onRefresh: () => _refreshAccess(silent: false),
        onLogout: () => GetIt.instance<AuthBloc>().add(SignOut()),
      )
          : IosAccessIntro(onStart: _loading ? null : _startTrial);
    }

    return Scaffold(
      backgroundColor: AppColors.colorBlue,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(_locked ? '⏰' : '🚀',
                      style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 14),
                  Text(
                    _locked
                        ? 'Пробный период закончился'
                        : 'Попробуй Formeo\nбесплатно 14 дней',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.colorWhite,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _locked
                        ? 'Выбери план чтобы продолжить работу с клиентами в Formeo.'
                        : 'Деньги не списываются пока не закончится пробный период.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.colorWhite.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Переключатель месяц/год ──
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.colorWhite.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _modeTab('Ежемесячно', _BillingMode.monthly),
                        _modeTab('Годовая  −67%', _BillingMode.yearly,
                            accentLabel: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Планы ──
                  if (_mode == _BillingMode.monthly) ...[
                    if (!_proOnly) ...[
                      _buildMonthlyCard(
                        plan: 'basic',
                        name: 'Basic',
                        price: '590 ₽',
                        period: 'в месяц',
                        features: const [
                          _Feature('Уведомления о тренировках', true),
                          _Feature('Учёт блоков и абонементов', true),
                          _Feature('Контроль оплат', true),
                          _Feature('Механизм удержания', false),
                          _Feature('Интеграция FatSecret', false),
                        ],
                        isPopular: false,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildMonthlyCard(
                      plan: 'pro',
                      name: 'Pro',
                      price: '990 ₽',
                      period: 'в месяц',
                      features: const [
                        _Feature('Уведомления о тренировках', true),
                        _Feature('Учёт блоков и абонементов', true),
                        _Feature('Контроль оплат', true),
                        _Feature('Механизм удержания', true),
                        _Feature('Интеграция FatSecret', true),
                      ],
                      isPopular: true,
                    ),
                  ] else
                    _buildYearlyCard(),

                  const SizedBox(height: 16),

                  // ── Заметка о триале ──
                  if (!_locked)
                    Text(
                      '14 дней бесплатно. Отменить можно в любой момент.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.35),
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 14),

                  // ── Чекбокс согласия с офертой — обязателен ──
                  _buildConsentCheckbox(),
                  const SizedBox(height: 10),

                  // ── Кнопка ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_loading || !_consentGiven) ? null : _subscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.colorDarkRed,
                        foregroundColor: AppColors.colorWhite,
                        disabledBackgroundColor:
                        AppColors.colorDarkRed.withValues(alpha: 0.35),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.colorWhite),
                      )
                          : Text(
                        _locked ? 'Продолжить' : 'Начать бесплатный период',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Крестик (нельзя закрыть если доступ истёк) ──
            if (!_locked)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _loading ? null : _startTrial,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.colorWhite.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.colorWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _consentGiven,
            onChanged: (v) => setState(() => _consentGiven = v ?? false),
            fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                  ? AppColors.colorDarkRed
                  : Colors.transparent,
            ),
            side: BorderSide(color: AppColors.colorWhite.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _consentGiven = !_consentGiven),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.colorWhite.withValues(alpha: 0.6),
                ),
                children: [
                  const TextSpan(text: 'Я согласен на автоматические списания согласно условиям '),
                  TextSpan(
                    text: 'оферты',
                    style: const TextStyle(
                      color: AppColors.colorWhite,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(Uri.parse(_ofertaUrl),
                          mode: LaunchMode.externalApplication),
                  ),
                  TextSpan(
                    text: _mode == _BillingMode.yearly
                        ? ' (списание 1 раз в год)'
                        : ' (списание 1 раз в месяц)',
                  ),
                  const TextSpan(text: '. Ознакомлен(а) с '),
                  TextSpan(
                    text: 'политикой конфиденциальности',
                    style: const TextStyle(
                      color: AppColors.colorWhite,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(Uri.parse(_privacyUrl),
                          mode: LaunchMode.externalApplication),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeTab(String label, _BillingMode mode,
      {bool accentLabel = false}) {
    final isActive = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mode = mode;
          _selectedPlan = mode == _BillingMode.monthly ? 'pro' : 'pro_yearly';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.colorWhite.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
              isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? AppColors.colorWhite
                  : AppColors.colorWhite.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyCard({
    required String plan,
    required String name,
    required String price,
    required String period,
    required List<_Feature> features,
    required bool isPopular,
  }) {
    final isSelected = _selectedPlan == plan;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPopular
                  ? AppColors.colorDarkRed.withValues(alpha: 0.1)
                  : AppColors.colorWhite.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.colorDarkRed
                    : isPopular
                    ? AppColors.colorDarkRed.withValues(alpha: 0.3)
                    : AppColors.colorWhite.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _RadioDot(selected: isSelected),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.colorWhite,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.colorWhite,
                          ),
                        ),
                        Text(
                          period,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.colorWhite.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...features.map((f) => _FeatureRow(feature: f)),
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: AppColors.colorDarkRed,
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(6)),
                ),
                child: const Text(
                  'Популярный',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearlyCard() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.colorDarkRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.colorDarkRed,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const _RadioDot(selected: true),
                      const SizedBox(width: 8),
                      const Text(
                        'Pro Годовая',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorWhite,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '3 960 ₽',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorWhite,
                        ),
                      ),
                      Text(
                        'в год · 330 ₽/мес',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.colorWhite.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '11 880 ₽',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorWhite.withValues(alpha: 0.4),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pill('Скидка 67%', const Color(0xFF34D399)),
                  const SizedBox(width: 6),
                  _pill('−7 920 ₽', const Color(0xFF34D399)),
                ],
              ),
              const SizedBox(height: 10),
              ...[
                const _Feature('Уведомления о тренировках', true),
                const _Feature('Учёт блоков и абонементов', true),
                const _Feature('Контроль оплат', true),
                const _Feature('Механизм удержания', true),
                const _Feature('Интеграция FatSecret', true),
              ].map((f) => _FeatureRow(feature: f)),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 12,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF34D399),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(6)),
            ),
            child: const Text(
              'Выгоднее всего',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A2E1F),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Вспомогательные классы ──

class _Feature {
  final String label;
  final bool enabled;
  const _Feature(this.label, this.enabled);
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            feature.enabled ? Icons.check : Icons.close,
            size: 14,
            color: feature.enabled
                ? const Color(0xFF34D399)
                : AppColors.colorWhite.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 6),
          Text(
            feature.label,
            style: TextStyle(
              fontSize: 12,
              color: feature.enabled
                  ? AppColors.colorWhite.withValues(alpha: 0.8)
                  : AppColors.colorWhite.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.colorDarkRed : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.colorDarkRed
              : AppColors.colorWhite.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Center(
        child: CircleAvatar(
          radius: 3,
          backgroundColor: AppColors.colorWhite,
        ),
      )
          : null,
    );
  }
}