import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/di.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/presentation/screens/auth_screen.dart';
import 'package:formeo/presentation/screens/register_screen.dart';
import 'package:formeo/presentation/screens/email_confirmation_screen.dart';
import 'package:formeo/presentation/screens/login_screen.dart';
import 'package:formeo/presentation/screens/loading_screen.dart';
import 'package:formeo/presentation/screens/main_screen.dart';
import 'package:formeo/presentation/screens/onboarding_screen.dart';
import 'package:formeo/presentation/screens/onboarding_info_screen.dart';
import 'package:formeo/presentation/screens/paywall_screen.dart';
import 'package:formeo/presentation/screens/create_workout_plan_screen.dart';
import 'package:formeo/presentation/screens/workout_generator_screen.dart';
import 'package:formeo/presentation/screens/notifications_screen.dart';
import 'package:formeo/presentation/screens/notification_detail_screen.dart';
import 'package:formeo/presentation/screens/client_details_screen.dart';
import 'package:formeo/presentation/screens/workout_plan_detail_screen.dart';
import 'package:formeo/presentation/screens/quick_workout_plan_detail_screen.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/presentation/screens/assign_quick_workout_plan_screen.dart';
import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/presentation/screens/workout_log_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription _sub;

  GoRouterRefreshStream(Stream stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ✅ Глобальный navigatorKey — нужен, чтобы можно было навигировать
// из мест без BuildContext (например, из PushNotificationService при
// тапе на push-уведомление, когда приложение свёрнуто/закрыто).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// ✅ ИСПРАВЛЕНИЕ: кэш флага онбординга — проверяем один раз за сессию,
// не делаем HTTP запрос при каждом переходе между экранами.
bool? _onboardingCompletedCache;

/// Вызывается из LoadingScreen после успешной проверки онбординга.
void setOnboardingCompleted(bool value) {
  _onboardingCompletedCache = value;
}

/// Сброс кэша при логауте.
void clearOnboardingCache() {
  _onboardingCompletedCache = null;
}

// ✅ ИСПРАВЛЕНИЕ: router — lazy getter вместо top-level final переменной.
//
// Проблема была в том, что `final GoRouter router = GoRouter(...)` инициализируется
// при первом импорте файла — то есть потенциально ДО вызова setupDI() в main().
// Кроме того, AuthBloc зарегистрирован как factory: getIt<AuthBloc>() внутри
// GoRouterRefreshStream создавал НОВЫЙ экземпляр блока, не связанный с тем,
// который живёт в дереве виджетов через BlocProvider. GoRouter слушал "мёртвый"
// bloc, и redirect не срабатывал при изменениях авторизации.
//
// Решение: функция createRouter() вызывается явно из main.dart ПОСЛЕ setupDI(),
// получает нужный singleton AuthBloc через getIt, и возвращает настроенный роутер.
GoRouter createRouter() {
  // AuthBloc — singleton в di.dart (registerLazySingleton),
  // поэтому getIt<AuthBloc>() здесь и context.read<AuthBloc>() в redirect
  // возвращают один и тот же экземпляр.
  final authBloc = getIt<AuthBloc>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/auth',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) async {
      final authState = context.read<AuthBloc>().state;
      final isAuthenticated = authState is AuthAuthenticated;
      final location = state.matchedLocation;

      debugPrint('🗺️ Router: authState=$authState, location=$location');

      final isOnAuthScreen = location == '/auth';
      final isOnLoginScreen = location == '/login';
      final isOnRegisterScreen = location == '/register';
      final isOnEmailConfirmation = location == '/email-confirmation';
      final isOnLoadingScreen = location == '/loading';
      final isOnMainScreen = location.startsWith('/main');
      final isOnOnboarding = location == '/onboarding';
      final isOnOnboardingInfo = location == '/onboarding-info';
      final isOnPaywall = location == '/paywall';

      // ── Не авторизован — гоним на /auth ──
      if (!isAuthenticated &&
          !isOnAuthScreen &&
          !isOnLoginScreen &&
          !isOnRegisterScreen &&
          !isOnEmailConfirmation) {
        debugPrint('🗺️ → /auth');
        clearOnboardingCache();
        return '/auth';
      }

      // ── Авторизован и на экране авторизации → /loading ──
      if (isAuthenticated &&
          (isOnAuthScreen || isOnLoginScreen || isOnRegisterScreen)) {
        debugPrint('🗺️ → /loading');
        return '/loading';
      }

      // ── Авторизован, онбординг завершён, но доступ истёк (триал кончился,
      //    подписка не активна) — гоним на закрытый пейволл везде,
      //    кроме самого пейволла и экранов входа/онбординга ──
      if (isAuthenticated &&
          _onboardingCompletedCache == true &&
          !isOnPaywall &&
          !isOnOnboarding &&
          !isOnOnboardingInfo &&
          !isOnLoadingScreen) {
        final user = getIt<UserProvider>().user;
        if (user != null && !user.hasAccess) {
          debugPrint('🗺️ → /paywall (доступ истёк)');
          return '/paywall';
        }
      }

      // ── Авторизован и на /onboarding-info — не трогаем ──
      if (isAuthenticated && isOnOnboardingInfo) {
        debugPrint('🗺️ → остаёмся на /onboarding-info');
        return null;
      }

      // ── Авторизован и на /paywall — не трогаем ──
      if (isAuthenticated && isOnPaywall) {
        debugPrint('🗺️ → остаёмся на /paywall');
        return null;
      }

      // ── Авторизован и на /onboarding — не трогаем ──
      if (isAuthenticated && isOnOnboarding) {
        debugPrint('🗺️ → остаёмся на /onboarding');
        return null;
      }

      // ── Авторизован и на /loading — не трогаем ──
      if (isAuthenticated && isOnLoadingScreen) {
        debugPrint('🗺️ → остаёмся на /loading');
        return null;
      }

      // ── Авторизован и на /main ──
      if (isAuthenticated && isOnMainScreen) {
        final cached = _onboardingCompletedCache;

        if (cached == null) {
          debugPrint('🗺️ → /loading (нет кэша онбординга)');
          return '/loading';
        }

        if (!cached) {
          debugPrint('🗺️ → /onboarding (не завершён)');
          return '/onboarding';
        }

        debugPrint('🗺️ → остаёмся на /main');
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: AuthScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: '/email-confirmation',
        pageBuilder: (context, state) {
          final email = state.extra as String? ?? '';
          return NoTransitionPage(
            child: EmailConfirmationScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: '/loading',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: LoadingScreen()),
      ),
      GoRoute(
        path: '/onboarding-info',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const OnboardingInfoScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const PaywallScreen()),
      ),
      GoRoute(
        path: '/main',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: MainScreen()),
      ),
      GoRoute(
        path: '/create-plan',
        name: 'createPlan',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: CreateWorkoutPlanScreen()),
      ),
      GoRoute(
        path: '/generator',
        name: 'generator',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: WorkoutGeneratorScreen()),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/notification-detail',
        name: 'notificationDetail',
        builder: (context, state) {
          final notificationItem = state.extra as NotificationItem;
          return NotificationDetailScreen(notification: notificationItem);
        },
      ),
      GoRoute(
        path: '/client-details',
        name: 'clientDetails',
        builder: (context, state) {
          // extra обычно приходит уже типизированным Client (см.
          // clients_screen.dart). Но при восстановлении состояния
          // навигации (например, на web после hot-restart/reload)
          // GoRouter может отдать сериализованный Map вместо объекта —
          // на этот случай конвертируем через Client.fromJson, чтобы
          // избежать `type 'Map<String, dynamic>' is not a subtype of
          // type 'Client'` при первом открытии экрана.
          final extra = state.extra;
          final client = extra is Client
              ? extra
              : Client.fromJson(Map<String, dynamic>.from(extra as Map));
          return ClientDetailsScreen(client: client);
        },
      ),
      GoRoute(
        path: '/workout-plan-detail',
        name: 'workoutPlanDetail',
        builder: (context, state) {
          final plan = state.extra as WorkoutPlan;
          return WorkoutPlanDetailScreen(plan: plan);
        },
      ),
      GoRoute(
        path: '/quick-workout-plan-detail',
        name: 'quickWorkoutPlanDetail',
        builder: (context, state) {
          final plan = state.extra as QuickWorkoutPlan;
          return QuickWorkoutPlanDetailScreen(plan: plan);
        },
      ),
      GoRoute(
        path: '/assign-quick-workout-plan',
        name: 'assignQuickWorkoutPlan',
        builder: (context, state) {
          final plan = state.extra as QuickWorkoutPlan;
          return AssignQuickWorkoutPlanScreen(plan: plan);
        },
      ),
      GoRoute(
        path: '/workout-log',
        name: 'workoutLog',
        builder: (context, state) {
          final schedule = state.extra as Schedule;
          return WorkoutLogScreen(schedule: schedule);
        },
      ),
    ],
  );
}
