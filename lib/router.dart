import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:coachsly/di.dart';
import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:coachsly/presentation/screens/auth_screen.dart';
import 'package:coachsly/presentation/screens/register_screen.dart';
import 'package:coachsly/presentation/screens/login_screen.dart';
import 'package:coachsly/presentation/screens/loading_screen.dart';
import 'package:coachsly/presentation/screens/main_screen.dart';
import 'package:coachsly/presentation/screens/create_workout_plan_screen.dart';
import 'package:coachsly/presentation/screens/workout_generator_screen.dart';
import 'package:coachsly/presentation/screens/notifications_screen.dart';
import 'package:coachsly/presentation/screens/client_details_screen.dart';
import 'package:coachsly/presentation/screens/add_schedule_entry_screen.dart';

import 'package:coachsly/presentation/screens/workout_plan_detail_screen.dart';
import 'package:coachsly/presentation/screens/quick_workout_plan_detail_screen.dart';
import 'package:coachsly/presentation/screens/client_workout_plan_detail_screen.dart';

import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/domain/entities/assigned_workout_plan.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream stream) {
    stream.listen((_) => notifyListeners());
  }
}

final GoRouter router = GoRouter(
  initialLocation: '/auth',
  refreshListenable: GoRouterRefreshStream(getIt<AuthBloc>().stream),
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;

    print('GoRouter redirect: state=$authState, location=${state.matchedLocation}');

    final isOnAuthScreen = state.matchedLocation == '/auth';
    final isOnLoginScreen = state.matchedLocation == '/login';
    final isOnRegisterScreen = state.matchedLocation == '/register';
    final isOnLoadingScreen = state.matchedLocation == '/loading';
    final isOnMainScreen = state.matchedLocation.startsWith('/main');

    if (!isAuthenticated && !isOnAuthScreen && !isOnLoginScreen && !isOnRegisterScreen) {
      print('Перенаправление на /auth');
      return '/auth';
    }

    if (isAuthenticated && (isOnAuthScreen || isOnLoginScreen || isOnRegisterScreen)) {
      print('Перенаправление на /loading');
      return '/loading';
    }

    if (isAuthenticated && isOnLoadingScreen) {
      print('Перенаправление на /main');
      return '/main';
    }

    if (isAuthenticated && isOnMainScreen) {
      print('Остаёмся на /main');
      return null;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => AuthScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => RegisterScreen(),
    ),
    GoRoute(
      path: '/loading',
      builder: (context, state) => LoadingScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => MainScreen(),
    ),
    GoRoute(
      path: '/create-plan',
      name: 'createPlan',
      builder: (context, state) => CreateWorkoutPlanScreen(),
    ),
    GoRoute(
      path: '/generator',
      name: 'generator',
      builder: (context, state) => WorkoutGeneratorScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => NotificationsScreen(),
    ),
    GoRoute(
      path: '/client-details',
      name: 'clientDetails',
      builder: (context, state) {
        final client = state.extra as Client;
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
    /*
    GoRoute(
      path: '/client-workout-plan-detail',
      name: 'clientWorkoutPlanDetail',
      builder: (context, state) {
        final plan = state.extra as AssignedWorkoutProgram;
        return ClientWorkoutPlanDetailScreen(plan: plan);
      },
    ),

     */
  ],
);