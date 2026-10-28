import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/ui/widgets/app_text_field.dart';
import 'package:formeo/ui/widgets/invitation_qr_card.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/router.dart' show setOnboardingCompleted;
import 'package:formeo/core/service/onboarding_progress_service.dart';
import 'package:formeo/core/service/pending_sync_service.dart';
import 'package:formeo/core/constants/billing_config.dart';

// ─────────────────────────────────────────────────────────────
//  Флоу онбординга (6 шагов):
//   Шаг 0 — Профиль (часовой пояс + локация)
//   Шаг 1 — Ссылка-приглашение (отправить клиенту)
//   Шаг 2 — Реквизиты + Стоимость
//   Шаг 3 — Fatsecret
//   Шаг 4 — Механизм удержания
//   Шаг 5 — Быстрая загрузка тренировочных программ (Pro)
//            → «Войти в приложение»
//
//  Шаг «Запись на тренировку» показывается уже внутри MainScreen
//  через FirstClientBookingDialog, как только клиент активирует ссылку.
// ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _saving = false;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // ── Шаг 0: Профиль ──
  final _locationController = TextEditingController();
  final List<String> _timezones = [
    'Europe/Kaliningrad',
    'Europe/Moscow',
    'Europe/Samara',
    'Asia/Yekaterinburg',
    'Asia/Omsk',
    'Asia/Krasnoyarsk',
    'Asia/Irkutsk',
    'Asia/Yakutsk',
    'Asia/Vladivostok',
    'Asia/Magadan',
    'Asia/Kamchatka',
  ];
  final Map<String, String> _timezoneLabels = {
    'Europe/Kaliningrad': 'Калининград (UTC+2)',
    'Europe/Moscow': 'Москва (UTC+3)',
    'Europe/Samara': 'Самара (UTC+4)',
    'Asia/Yekaterinburg': 'Екатеринбург (UTC+5)',
    'Asia/Omsk': 'Омск (UTC+6)',
    'Asia/Krasnoyarsk': 'Красноярск (UTC+7)',
    'Asia/Irkutsk': 'Иркутск (UTC+8)',
    'Asia/Yakutsk': 'Якутск (UTC+9)',
    'Asia/Vladivostok': 'Владивосток (UTC+10)',
    'Asia/Magadan': 'Магадан (UTC+11)',
    'Asia/Kamchatka': 'Камчатка (UTC+12)',
  };
  String _selectedTimezone = 'Europe/Moscow';

  // ── Шаг 2: Реквизиты и стоимость ──
  final _phoneController = TextEditingController();
  final _bankController = TextEditingController();
  final _singlePriceController = TextEditingController();
  final _blockPriceController = TextEditingController();
  final _blockSessionsController = TextEditingController();
  final _subscriptionPriceController = TextEditingController();
  final _subscriptionDaysController = TextEditingController();

  // ── Шаг 3: Fatsecret ──
  bool _fatsecretNeeded = false;

  // ── Шаг 4: Механизм удержания ──
  bool _retentionEnabled = false;

  // Шаги 5–10 в глобальном прогресс-баре (0–4 заняты info screen)
  static const int _globalStepOffset = 5;

  @override
  void initState() {
    super.initState();
    final user = GetIt.instance<UserProvider>().user;
    if (user != null && _timezones.contains(user.timezone)) {
      _selectedTimezone = user.timezone;
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Синхронизируем глобальный прогресс — продолжаем с шага 5
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GetIt.instance<OnboardingProgressService>().setStep(_globalStepOffset);
    });
    // Пробуем досохранить то, что не удалось сохранить раньше из-за сети
    GetIt.instance<PendingSyncService>().flushAll();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _bankController.dispose();
    _singlePriceController.dispose();
    _blockPriceController.dispose();
    _blockSessionsController.dispose();
    _subscriptionPriceController.dispose();
    _subscriptionDaysController.dispose();
    super.dispose();
  }

  // ── Утилиты ──

  String _getCurrentTimeInZone(String timezone) {
    try {
      final location = tz.getLocation(timezone);
      final tzNow = tz.TZDateTime.from(_now, location);
      final h = tzNow.hour.toString().padLeft(2, '0');
      final m = tzNow.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      final h = _now.hour.toString().padLeft(2, '0');
      final m = _now.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Завершает онбординг и переходит в приложение.
  Future<void> _completeOnboarding() async {
    final user = GetIt.instance<UserProvider>().user;
    if (user == null) return;
    try {
      await GetIt.instance<SupabaseDataSource>().completeOnboarding(user.id);
      setOnboardingCompleted(true);
    } catch (_) {}
    final proOnly = _retentionEnabled || _fatsecretNeeded;
    if (mounted) context.go('/paywall', extra: {'proOnly': proOnly});
  }

  // ── Сохранение данных ──

  Future<void> _saveStep0() async {
    setState(() => _saving = true);
    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>().updateTrainerProfile(
        trainerId: user.id,
        timezone: _selectedTimezone,
        location:
        _locationController.text.isNotEmpty ? _locationController.text : null,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Сохранение не критично — кладём в очередь и идём дальше.
      // Данные синхронизируются при следующем запуске через PendingSyncService.
      debugPrint('_saveStep0: не удалось сохранить профиль: $e');
      final user = GetIt.instance<UserProvider>().user;
      if (user != null) {
        await GetIt.instance<PendingSyncService>().queueTrainerProfile(
          user.id,
          {
            'timezone': _selectedTimezone,
            'location': _locationController.text.isNotEmpty
                ? _locationController.text
                : null,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Сохраняет реквизиты в фоне. Не блокирует UI и не показывает ошибки —
  /// тренер может заполнить эти данные позже в настройках, если запрос не пройдёт.
  Future<void> _saveStep2() async {
    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>().saveTrainerPaymentDetails(
        trainerId: user.id,
        phoneNumber: _phoneController.text,
        preferredBank:
        _bankController.text.isNotEmpty ? _bankController.text : null,
        singlePrice: _singlePriceController.text.isNotEmpty
            ? double.tryParse(_singlePriceController.text)
            : null,
        blockPrice: _blockPriceController.text.isNotEmpty
            ? double.tryParse(_blockPriceController.text)
            : null,
        blockSessions: _blockSessionsController.text.isNotEmpty
            ? int.tryParse(_blockSessionsController.text)
            : null,
        subscriptionPrice: _subscriptionPriceController.text.isNotEmpty
            ? double.tryParse(_subscriptionPriceController.text)
            : null,
        subscriptionDays: _subscriptionDaysController.text.isNotEmpty
            ? int.tryParse(_subscriptionDaysController.text)
            : null,
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Не удалось сохранить реквизиты, кладём в очередь: $e');
      final user = GetIt.instance<UserProvider>().user;
      if (user != null) {
        await GetIt.instance<PendingSyncService>().queuePaymentDetails(
          user.id,
          {
            'phoneNumber': _phoneController.text,
            'preferredBank': _bankController.text.isNotEmpty
                ? _bankController.text
                : null,
            'singlePrice': _singlePriceController.text.isNotEmpty
                ? double.tryParse(_singlePriceController.text)
                : null,
            'blockPrice': _blockPriceController.text.isNotEmpty
                ? double.tryParse(_blockPriceController.text)
                : null,
            'blockSessions': _blockSessionsController.text.isNotEmpty
                ? int.tryParse(_blockSessionsController.text)
                : null,
            'subscriptionPrice': _subscriptionPriceController.text.isNotEmpty
                ? double.tryParse(_subscriptionPriceController.text)
                : null,
            'subscriptionDays': _subscriptionDaysController.text.isNotEmpty
                ? int.tryParse(_subscriptionDaysController.text)
                : null,
          },
        );
      }
    }
  }

  Future<void> _saveFatsecret(bool value) async {
    // Оптимистично обновляем UI сразу
    setState(() => _fatsecretNeeded = value);
    final user = GetIt.instance<UserProvider>().user!;
    try {
      await GetIt.instance<SupabaseDataSource>()
          .setFatsecretNeeded(user.id, value)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('FatSecret: сохранение не удалось, кладём в очередь: $e');
      await GetIt.instance<PendingSyncService>().queueFatsecret(user.id, value);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorBlue,
      body: SafeArea(
        child: Column(
          children: [
            // ── Глобальный прогресс-бар ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: OnboardingProgressBar(),
            ),

            // ── Контент ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  GetIt.instance<OnboardingProgressService>()
                      .setStep(_globalStepOffset + i);
                },
                children: [
                  _buildStep1Invitation(),
                  _buildStep0Profile(),
                  _buildStep2Payment(),
                  _buildStep2bFatsecret(),
                  _buildStep3Retention(),
                  _buildStep4QuickWorkoutPlans(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Шаг 0: Профиль
  // ─────────────────────────────────────────────────────────────

  Widget _buildStep0Profile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.person_outline,
            step: null,
            title: 'Расскажите о себе',
            subtitle:
            'Укажите локацию и часовой пояс — это поможет корректно отображать расписание',
          ),
          const SizedBox(height: 32),

          const Text(
            'Часовой пояс',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.colorWhite,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 15, color: AppColors.colorWhite.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'Ваше текущее время — ${_getCurrentTimeInZone(_selectedTimezone)}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.colorWhite.withValues(alpha: 0.55)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: _selectedTimezone,
            dropdownColor: AppColors.colorWhite,
            style: const TextStyle(color: AppColors.colorBlue, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.colorWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _timezones
                .map((tz) => DropdownMenuItem(
              value: tz,
              child: Text(
                _timezoneLabels[tz] ?? tz,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.colorBlue),
              ),
            ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedTimezone = val);
            },
          ),
          const SizedBox(height: 20),

          AppTextField(
            label: 'Локация — место где вы проводите занятия',
            hint: 'Москва, зал FitnessPro, ул. Ленина 1',
            controller: _locationController,
          ),
          const SizedBox(height: 40),

          _buildNextButton(
            label: 'Далее',
            onTap: () async {
              await _saveStep0();
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Шаг 1: Ссылка-приглашение
  // ─────────────────────────────────────────────────────────────

  Widget _buildStep1Invitation() {
    final user = GetIt.instance<UserProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.link_rounded,
            step: null,
            title: 'Пригласите клиента',
            subtitle:
            'Отправьте ссылку — как только клиент перейдёт по ней, вы сразу это увидите',
          ),
          const SizedBox(height: 32),

          _InvitationWidget(trainerId: user.id),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.colorWhite.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: AppColors.colorWhite.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.group_outlined,
                    color: AppColors.colorWhite.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ссылка одна для всех. Отправь её сразу всем своим клиентам — каждый, кто перейдёт и напишет боту в Telegram или MAX, появится в твоём списке.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.colorWhite.withValues(alpha: 0.8),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.colorWhite.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: AppColors.colorWhite.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    color: AppColors.colorWhite.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Пока клиент активирует ссылку — заполните реквизиты и настройте стоимость.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.colorWhite.withValues(alpha: 0.8),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _buildNextButton(
            label: 'Далее',
            onTap: _nextPage,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Шаг 2: Реквизиты и стоимость
  // ─────────────────────────────────────────────────────────────

  Widget _buildStep2Payment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.payments_outlined,
            step: null,
            title: 'Как клиенты будут платить',
            subtitle: 'Бот будет отправлять эти данные клиентам автоматически',
          ),
          const SizedBox(height: 24),

          AppTextField(
            label: 'Номер телефона для СБП',
            hint: '+7 (999) 123-45-67',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Предпочитаемый банк',
            hint: 'Сбербанк, Тинькофф...',
            controller: _bankController,
          ),
          const SizedBox(height: 20),

          _sectionLabel('Стоимость тренировок'),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Разовая тренировка (₽)',
            hint: '1500',
            controller: _singlePriceController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'Блок тренировок (₽)',
                  hint: '8500',
                  controller: _blockPriceController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: 'Кол-во',
                  hint: '10',
                  controller: _blockSessionsController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'Абонемент (₽)',
                  hint: '12500',
                  controller: _subscriptionPriceController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: 'Срок (дней)',
                  hint: '30',
                  controller: _subscriptionDaysController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.colorWhite.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: AppColors.colorWhite.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    color: AppColors.colorWhite.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Эти данные всегда можно заполнить или изменить позже в настройках профиля.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.colorWhite.withValues(alpha: 0.8),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildNextButton(
            label: 'Далее',
            onTap: () {
              _saveStep2(); // сохраняем в фоне, не блокируем переход
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Шаг 2b: FatSecret
  // ─────────────────────────────────────────────────────────────

  Widget _buildStep2bFatsecret() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.restaurant_menu_outlined,
            step: null,
            proBadge: true,
            title: 'Следишь за питанием клиентов?',
            subtitle:
            'Formeo умеет подключаться к FatSecret и показывать данные о питании в профиле клиента',
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.colorWhite.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _fatsecretNeeded
                    ? AppColors.colorDarkRed.withValues(alpha: 0.6)
                    : AppColors.colorWhite.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Подключить FatSecret',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fatsecretNeeded
                            ? 'Включено — клиенты будут делиться КБЖУ'
                            : 'Выключено',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.colorWhite.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _fatsecretNeeded,
                  activeColor: AppColors.colorDarkRed,
                  onChanged: _saveFatsecret,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Powered by FatSecret',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.colorWhite.withValues(alpha: 0.35),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 32),

          _buildNextButton(
            label: 'Далее',
            onTap: _nextPage,
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────
  //  Шаг 3: Механизм удержания
  // ─────────────────────────────────────────────────────────────

  Future<void> _saveRetention(bool value) async {
    // Оптимистично обновляем UI сразу
    setState(() => _retentionEnabled = value);
    final user = GetIt.instance<UserProvider>().user!;
    try {
      await GetIt.instance<SupabaseDataSource>()
          .setRetentionEnabled(user.id, value)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Retention: сохранение не удалось, кладём в очередь: $e');
      await GetIt.instance<PendingSyncService>().queueRetention(user.id, value);
    }
  }

  Widget _buildStep3Retention() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.monitor_heart_outlined,
            step: null,
            proBadge: true,
            title: 'Механизм удержания',
            subtitle:
            'Включи чтобы Formeo следил за каждым клиентом и предупреждал тебя заранее',
          ),
          const SizedBox(height: 28),

          // ── Тумблер ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.colorWhite.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _retentionEnabled
                    ? AppColors.colorDarkRed.withValues(alpha: 0.6)
                    : AppColors.colorWhite.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Включить механизм удержания',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _retentionEnabled
                            ? 'Включено — Formeo следит за клиентами'
                            : 'Выключено — только базовые функции',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.colorWhite.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _retentionEnabled,
                  activeColor: AppColors.colorDarkRed,
                  onChanged: _saveRetention,
                ),
              ],
            ),
          ),

          // ── Подтверждение ──
          if (_retentionEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF34D399), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Включено. Formeo будет присматривать за активностю клиентов и присылать тебе сигналы',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF34D399),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildRetentionFeatures(),
          ],

          const SizedBox(height: 32),

          _buildNextButton(
            label: 'Далее',
            onTap: _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionFeatures() {
    final items = [
      (Icons.circle, const Color(0xFFEF4444),
      'Красный сигнал', 'Пропустил две тренировки подряд или самочувствие упало'),
      (Icons.circle, const Color(0xFFF59E0B),
      'Жёлтый сигнал', 'Ходит заметно реже чем обычно'),
      (Icons.chat_bubble_outline, const Color(0xFFA78BFA),
      'Чек-ин', 'Бот спрашивает клиента как дела каждые две недели'),
      (Icons.show_chart, const Color(0xFF60A5FA),
      'Прогресс-срез', 'Клиент видит свою статистику раз в месяц'),
    ];

    return Column(
      children: items.map((item) {
        final (icon, color, title, desc) = item;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$title  ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorWhite,
                        ),
                      ),
                      TextSpan(
                        text: desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.colorWhite.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Шаг 4: Быстрая загрузка тренировочных программ (Pro)
  // ─────────────────────────────────────────────────────────────

  Widget _buildStep4QuickWorkoutPlans() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.flash_on,
            step: null,
            proBadge: true,
            title: 'Быстрая загрузка программ',
            subtitle:
            'Не переноси тренировки вручную — просто вставь готовый текст программы, а Formeo сам разложит его по дням и упражнениям',
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.colorWhite.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.colorWhite.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined,
                    color: AppColors.colorWhite.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Программа уже есть в заметках, вордовском файле или чате с клиентом? '
                        'Просто вставь текст целиком — по всем дням сразу.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.colorWhite.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildQuickPlanFeatures(),

          if (BillingConfig.inAppPaymentsAllowed) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Доступно на тарифе Pro',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.colorWhite.withValues(alpha: 0.35),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),

          _buildNextButton(
            label: 'Войти в приложение',
            onTap: _completeOnboarding,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPlanFeatures() {
    final items = [
      (Icons.auto_awesome, const Color(0xFFA78BFA),
      'Распознавание ИИ', 'Дни, упражнения, подходы и повторения — из обычного текста'),
      (Icons.person_add_alt_1, const Color(0xFF60A5FA),
      'Назначение в клик', 'Выбери клиента — программа сразу привязана к нему'),
      (Icons.fitness_center, const Color(0xFFF59E0B),
      'Фиксация прогресса', 'Записывай вес и повторения прямо с карточки тренировки на дашборде'),
      (Icons.show_chart, const Color(0xFF34D399),
      'История клиента', 'Вся динамика по тренировкам — в карточке клиента'),
    ];

    return Column(
      children: items.map((item) {
        final (icon, color, title, desc) = item;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$title  ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorWhite,
                        ),
                      ),
                      TextSpan(
                        text: desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.colorWhite.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }


  // ── Вспомогательные виджеты ──

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: AppColors.colorWhite,
    ),
  );

  Widget _buildStepHeader({
    required IconData icon,
    String? step,
    required String title,
    required String subtitle,
    bool proBadge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.colorDarkRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.colorWhite, size: 24),
            ),
            // iOS: без упоминаний тарифов (правило App Store 3.1.1).
            if (proBadge && BillingConfig.inAppPaymentsAllowed) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.colorDarkRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.colorDarkRed.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorDarkRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.colorWhite,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.colorWhite.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.colorDarkRed,
          foregroundColor: AppColors.colorWhite,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _saving
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.colorWhite),
        )
            : Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Виджет-приглашение (переключатель Telegram/MAX + QR + ссылка)
// ─────────────────────────────────────────────────────────────

class _InvitationWidget extends StatefulWidget {
  final String trainerId;
  const _InvitationWidget({required this.trainerId});

  @override
  State<_InvitationWidget> createState() => _InvitationWidgetState();
}

class _InvitationWidgetState extends State<_InvitationWidget> {
  String? _token;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateInvitation();
  }

  Future<void> _generateInvitation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = GetIt.instance<ClientRepository>();
      final token = await repo
          .createInvitation(widget.trainerId)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _token = token;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось создать ссылку';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.colorWhite),
        ),
      );
    }

    if (_error != null || _token == null) {
      return Column(
        children: [
          Text(_error ?? 'Не удалось создать ссылку',
              style: TextStyle(
                  color: AppColors.colorWhite.withValues(alpha: 0.7), fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _generateInvitation,
            icon: const Icon(Icons.refresh, color: AppColors.colorWhite),
            label: const Text('Попробовать снова',
                style: TextStyle(color: AppColors.colorWhite)),
          ),
        ],
      );
    }

    // Переключатель Telegram/MAX, QR, ссылка и «Отправить клиенту»
    return InvitationQrCard(
      token: _token!,
      style: InvitationCardStyle.onDark,
    );
  }
}