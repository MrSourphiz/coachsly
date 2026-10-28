import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:formeo/presentation/providers/splash_progress_provider.dart';
import 'package:formeo/presentation/providers/notifications_provider.dart';
import 'package:formeo/presentation/providers/user_provider.dart';

class SplashWrapper extends StatefulWidget {
  final Widget child;
  const SplashWrapper({super.key, required this.child});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _appReady = false;
  bool _dataLoaded = false;
  DateTime? _lastResubscribeTime;

  StreamSubscription<supa.AuthState>? _supabaseAuthSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _simulateInitialProgress();
    _listenSupabaseAuth();
  }

  /// Слушаем onAuthStateChange напрямую из Supabase SDK.
  ///
  /// signedIn  — пользователь перешёл по deeplink из письма подтверждения.
  ///             AuthBloc не знает об этом событии, поэтому вызываем CheckAuth.
  ///
  /// signedOut — Supabase сам разлогинил пользователя (невалидный refresh token).
  ///             Без обработки AuthBloc остаётся в AuthAuthenticated с кэшем роли
  ///             и пользователь попадает на онбординг вместо экрана входа.
  void _listenSupabaseAuth() {
    _supabaseAuthSubscription = supa.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      debugPrint('🔑 SplashWrapper: Supabase auth event = ${data.event}');

      if (data.event == supa.AuthChangeEvent.signedIn && data.session != null) {
        final currentState = GetIt.I<AuthBloc>().state;
        if (currentState is AuthAuthenticated) return;

        debugPrint('🔑 SplashWrapper: email confirmed via deeplink → ensureUserRecord + CheckAuth');
        // Гарантируем что запись в public.users существует до CheckAuth.
        // Триггер handle_new_user создаёт её при INSERT в auth.users,
        // но для пользователей зарегистрированных до этого изменения
        // записи может не быть — создаём вручную как fallback.
        await _ensureUserRecord(data.session!);
        GetIt.I<AuthBloc>().add(CheckAuthStatusEvent());
      }

      if (data.event == supa.AuthChangeEvent.signedOut) {
        // Проверяем что AuthBloc ещё не в состоянии Unauthenticated —
        // иначе получаем бесконечный цикл:
        // signOut → signedOut event → SignOut → signOut → ...
        final currentState = GetIt.I<AuthBloc>().state;
        if (currentState is AuthUnauthenticated) return;
        debugPrint('🔑 SplashWrapper: Supabase signedOut → SignOut');
        GetIt.I<AuthBloc>().add(SignOut());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _supabaseAuthSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _appReady) {
      final now = DateTime.now();
      if (_lastResubscribeTime != null &&
          now.difference(_lastResubscribeTime!).inSeconds < 30) {
        return;
      }
      _lastResubscribeTime = now;
      _resubscribeInBackground();
    }
  }

  /// Проверяет что запись в public.users существует.
  /// Если нет — создаёт её. Вызывается после подтверждения email
  /// чтобы гарантировать наличие записи до CheckAuthStatusEvent.
  Future<void> _ensureUserRecord(supa.Session session) async {
    try {
      const storage = FlutterSecureStorage();
      final cachedRole = await storage.read(key: 'cached_user_role') ?? 'trainer';
      final cachedTimezone = await storage.read(key: 'cached_user_timezone') ?? 'Europe/Moscow';

      final ds = GetIt.I<SupabaseDataSource>();

      // Проверяем есть ли запись
      try {
        final existing = await ds.getUserData(session.user.id);
        if (existing.isNotEmpty) {
          debugPrint('🔑 _ensureUserRecord: запись уже есть');
          return;
        }
      } catch (_) {
        // Записи нет — создаём
      }

      debugPrint('🔑 _ensureUserRecord: создаём запись в public.users');
      await ds.addUser({
        'id': session.user.id,
        'email': session.user.email,
        'role': cachedRole,
        'timezone': cachedTimezone,
      });
      debugPrint('🔑 _ensureUserRecord: запись создана');
    } catch (e) {
      // Не критично — CheckAuth сделает retry
      debugPrint('🔑 _ensureUserRecord: ошибка: $e');
    }
  }

  void _resubscribeInBackground() {
    final userId = GetIt.I<UserProvider>().user?.id;
    if (userId == null) return;

    debugPrint('🔄 SplashWrapper: app resumed, resubscribing realtime silently');

    final scheduleBloc = GetIt.I<ScheduleBloc>();
    final clientBloc = GetIt.I<ClientBloc>();

    scheduleBloc.add(ResubscribeSchedules(userId));
    clientBloc.add(ResubscribeClients(userId));

    final notificationsProvider = context.read<NotificationsProvider?>();
    notificationsProvider?.resubscribe();
  }

  void _simulateInitialProgress() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _updateProgress(0.2, 'Проверка подключения...');
    await Future.delayed(const Duration(milliseconds: 400));
    _updateProgress(0.4, 'Загрузка конфигурации...');
    await Future.delayed(const Duration(milliseconds: 300));
    _updateProgress(0.6, 'Проверка авторизации...');
  }

  void _updateProgress(double value, String text) {
    if (mounted) {
      context.read<SplashProgressProvider>().setProgress(value, text);
    }
  }

  void _onDataReady() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _appReady = true);
    });
  }

  void _startLoadingData(String userId) {
    debugPrint('🔵 SplashWrapper: starting data load for userId=$userId');

    _updateProgress(0.8, 'Загрузка данных...');

    final scheduleBloc = GetIt.I<ScheduleBloc>();
    final clientBloc = GetIt.I<ClientBloc>();

    scheduleBloc.add(SubscribeSchedules(userId));
    clientBloc.add(SubscribeClients(userId));

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      debugPrint('🟢 SplashWrapper: subscriptions started, opening app');
      _updateProgress(1.0, 'Готово!');
      _onDataReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        debugPrint('🔵 SplashWrapper: AuthBloc state = $state');

        if (state is AuthAuthenticated) {
          if (_dataLoaded) {
            debugPrint(
                '🟡 SplashWrapper: already loaded, skipping re-init (token refresh?)');
            return;
          }

          debugPrint('🟢 SplashWrapper: authenticated, first load');
          _updateProgress(0.75, 'Загрузка...');

          try {
            final dataSource = GetIt.instance<SupabaseDataSource>();
            final onboardingCompleted =
            await dataSource.isOnboardingCompleted(state.user.id);

            if (!mounted) return;

            if (!onboardingCompleted) {
              debugPrint('🟢 SplashWrapper: new user → skip data load');
              _dataLoaded = true;
              _updateProgress(1.0, 'Готово!');
              _onDataReady();
            } else {
              debugPrint('🟢 SplashWrapper: existing user → load data');
              _dataLoaded = true;
              _startLoadingData(state.user.id);
            }
          } catch (e) {
            debugPrint('🔴 SplashWrapper: error checking onboarding: $e');
            _dataLoaded = true;
            _startLoadingData(state.user.id);
          }
        } else if (state is AuthUnauthenticated) {
          _dataLoaded = false;

          debugPrint('🟡 SplashWrapper: unauthenticated, going to auth screen');
          _updateProgress(1.0, 'Готово!');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) setState(() => _appReady = true);
            });
          });
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _appReady ? widget.child : _buildSplash(),
      ),
    );
  }

  Widget _buildSplash() {
    return Directionality(
      key: const ValueKey('splash'),
      textDirection: TextDirection.ltr,
      child: Consumer<SplashProgressProvider>(
        builder: (context, splash, _) {
          return Material(
            color: AppColors.colorBlue,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.colorDarkRed,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.colorDarkRed.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Formeo',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.colorWhite,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Держи дела в форме',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.colorWhite.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Column(
                          children: [
                            Text(
                              splash.statusText,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.colorWhite.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: splash.progress),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 6,
                                    backgroundColor:
                                    AppColors.colorWhite.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.colorDarkRed,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
