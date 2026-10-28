import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:formeo/core/network/dio_client.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/data/sources/workout_generator_remote_data_source.dart';
import 'package:formeo/data/repositories/auth_repository_impl.dart';
import 'package:formeo/data/repositories/client_repository_impl.dart';
import 'package:formeo/data/repositories/exrcises_repository_impl.dart';
import 'package:formeo/data/repositories/notifications_repository_impl.dart';
import 'package:formeo/data/repositories/payment_repository_impl.dart';
import 'package:formeo/data/repositories/schedule_repository_impl.dart';
import 'package:formeo/data/repositories/training_diary_repository_impl.dart';
import 'package:formeo/data/repositories/workout_generator_repository_impl.dart';
import 'package:formeo/data/repositories/workout_plan_repository_impl.dart';
import 'package:formeo/data/repositories/retention_repository_impl.dart';

import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/domain/repositories/exercises_repository.dart';
import 'package:formeo/domain/repositories/notifications_repository.dart';
import 'package:formeo/domain/repositories/payment_repository.dart';
import 'package:formeo/domain/repositories/schedule_repository.dart';
import 'package:formeo/domain/repositories/training_diary_repository.dart';
import 'package:formeo/domain/repositories/workout_generator_repository.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/repositories/retention_repository.dart';

import 'package:formeo/domain/usecases/auth_user.dart';
import 'package:formeo/domain/usecases/login_user.dart';
import 'package:formeo/domain/usecases/register_user.dart';
import 'package:formeo/domain/usecases/logout_user.dart';
import 'package:formeo/domain/usecases/check_auth.dart';
import 'package:formeo/domain/usecases/check_auth_status.dart';
import 'package:formeo/domain/usecases/get_schedules.dart';
import 'package:formeo/domain/usecases/book_session.dart';
import 'package:formeo/domain/usecases/get_workout_plans.dart';
import 'package:formeo/domain/usecases/get_quick_workout_plans.dart';
import 'package:formeo/domain/usecases/get_clients_workout_plans.dart';
import 'package:formeo/domain/usecases/assign_workout_plan.dart';
import 'package:formeo/domain/usecases/update_assigned_workout_plan.dart';
import 'package:formeo/domain/usecases/delete_assigned_workout_plan.dart';
import 'package:formeo/domain/usecases/create_workout_plan.dart';
import 'package:formeo/domain/usecases/get_training_diary_entries.dart';
import 'package:formeo/domain/usecases/generate_workout_plan.dart';
import 'package:formeo/domain/usecases/retention_usecases.dart';
import 'package:formeo/domain/usecases/assign_quick_workout_plan.dart';

import 'package:formeo/presentation/blocs/auth_bloc.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/blocs/workout_plan_bloc.dart';
import 'package:formeo/presentation/blocs/quick_workout_plan_bloc.dart';
import 'package:formeo/presentation/blocs/client_workout_plan_bloc.dart';
import 'package:formeo/presentation/blocs/training_diary_bloc.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:formeo/presentation/blocs/exercises_bloc.dart';
import 'package:formeo/presentation/blocs/workout_generator_bloc.dart';
import 'package:formeo/presentation/blocs/retention_bloc.dart';

import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/presentation/providers/notifications_provider.dart';
import 'package:formeo/core/service/onboarding_progress_service.dart';
import 'package:formeo/core/service/pending_sync_service.dart';

import 'package:formeo/core/service/push_notification_service.dart';
import 'package:formeo/core/service/robokassa_subscription_service.dart';

import 'package:formeo/data/repositories/workout_log_repository_impl.dart';
import 'package:formeo/domain/repositories/workout_log_repository.dart';

import 'package:formeo/data/repositories/body_measurements_repository_impl.dart';
import 'package:formeo/domain/repositories/body_measurements_repository.dart';

final getIt = GetIt.instance;

void setupDI() {
  // ========= UserProvider =========
  getIt.registerSingleton<UserProvider>(UserProvider());

  // ========= SupabaseClient =========
  getIt.registerSingleton<SupabaseClient>(
    Supabase.instance.client,
  );

  // ========= DioClient =========
  getIt.registerLazySingleton<DioClient>(() => DioClient());

  // ========= SupabaseDataSource =========
  getIt.registerLazySingleton<SupabaseDataSource>(
        () => SupabaseDataSource(getIt<SupabaseClient>()),
  );

  // ========= Services =========
  getIt.registerLazySingleton<OnboardingProgressService>(() => OnboardingProgressService());
  getIt.registerLazySingleton<PendingSyncService>(() => PendingSyncService());
  getIt.registerLazySingleton<PushNotificationService>(
        () => PushNotificationService(),
  );
  getIt.registerLazySingleton<RobokassaSubscriptionService>(
        () => RobokassaSubscriptionService(getIt<SupabaseClient>()),
  );

  // ========= Workout Generator =========
  getIt.registerLazySingleton<WorkoutGeneratorRemoteDataSource>(
        () => WorkoutGeneratorRemoteDataSourceImpl(
      dio: getIt<DioClient>().dio,
    ),
  );
  getIt.registerLazySingleton<WorkoutGeneratorRepository>(
        () => WorkoutGeneratorRepositoryImpl(
      remoteDataSource: getIt<WorkoutGeneratorRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton(
        () => GenerateWorkoutPlan(getIt<WorkoutGeneratorRepository>()),
  );
  getIt.registerFactory(
        () => WorkoutGeneratorBloc(
      generateWorkoutPlan: getIt<GenerateWorkoutPlan>(),
    ),
  );

  // ========= Repositories =========
  getIt.registerLazySingleton<NotificationsRepository>(
        () => NotificationsRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  getIt.registerLazySingleton<ExercisesRepository>(
        () => ExerciseRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  getIt.registerLazySingleton<ScheduleRepository>(
        () => ScheduleRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  getIt.registerLazySingleton<WorkoutPlanRepository>(
        () => WorkoutPlanRepositoryImpl(getIt<SupabaseDataSource>()),
  );

  getIt.registerLazySingleton<WorkoutLogRepository>(
        () => WorkoutLogRepositoryImpl(getIt<SupabaseDataSource>()),
  );

  getIt.registerLazySingleton<TrainingDiaryRepository>(
        () => TrainingDiaryRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  getIt.registerLazySingleton<ClientRepository>(
        () => ClientRepositoryImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<PaymentRepository>(
        () => PaymentRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  // ========= Retention Repository =========
  getIt.registerLazySingleton<RetentionRepository>(
        () => RetentionRepositoryImpl(getIt<SupabaseClient>()),
  );

  // ========= Body Measurements Repository =========
  getIt.registerLazySingleton<BodyMeasurementsRepository>(
        () => BodyMeasurementsRepositoryImpl(getIt<SupabaseClient>()),
  );

  // ========= Use Cases =========
  getIt.registerLazySingleton(() => AuthenticateUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LoginUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => RegisterUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => CheckAuth(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => CheckAuthStatus(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => GetSchedules(getIt<ScheduleRepository>()));
  getIt.registerLazySingleton(() => BookSession(getIt<ScheduleRepository>()));
  getIt.registerLazySingleton(() => GetWorkoutPlans(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => GetQuickWorkoutPlans(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => GetClientsWorkoutPlans(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => UpdateAssignedWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => DeleteAssignedWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => CreateWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => GetTrainingDiaryEntries(getIt<TrainingDiaryRepository>()));
  getIt.registerLazySingleton(() => AssignWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => AssignQuickWorkoutPlan(getIt<WorkoutPlanRepository>())); // ← новая строка
  // ========= Retention Use Cases =========
  getIt.registerLazySingleton(() => CheckOnboardingCompleted(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => GetRetentionOnboarding(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => SaveRetentionOnboarding(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => CheckCheckinDue(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => SaveRetentionCheckin(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => GetRetentionCheckins(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => GetActiveRetentionSignals(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => ResolveRetentionSignal(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(() => GetClientProgressSummary(getIt<RetentionRepository>()));
  getIt.registerLazySingleton(
        () => SetRetentionEnabled(getIt<RetentionRepository>()),
  );
  getIt.registerLazySingleton(
        () => GetRetentionEnabled(getIt<RetentionRepository>()),
  );
  getIt.registerLazySingleton(
        () => TriggerOnboardingStart(getIt<RetentionRepository>()),
  );

  // ========= Providers =========
  getIt.registerFactoryParam<NotificationsProvider, String, void>(
        (trainerId, _) => NotificationsProvider(
      trainerId: trainerId,
      repository: getIt<NotificationsRepository>(),
    ),
  );

  // ========= BLoC =========

  // AuthBloc — lazySingleton: один экземпляр на всю сессию.
  // Роутер (createRouter) и дерево виджетов (BlocProvider) должны работать
  // с одним и тем же экземпляром — иначе GoRouterRefreshStream слушает
  // "мёртвый" блок и redirect не срабатывает при изменениях авторизации.
  // При логауте состояние сбрасывается через SignOut event, а не пересозданием.
  getIt.registerLazySingleton<AuthBloc>(
        () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );

  // ScheduleBloc — singleton: один экземпляр, realtime-подписка живёт всю сессию
  getIt.registerLazySingleton<ScheduleBloc>(
        () => ScheduleBloc(
      getSchedules: getIt<GetSchedules>(),
      bookSession: getIt<BookSession>(),
    ),
  );

  // ✅ ClientBloc — singleton: один экземпляр, realtime-подписка живёт всю сессию.
  // Было registerFactory — каждый вызов GetIt.I<ClientBloc>() давал НОВЫЙ экземпляр,
  // поэтому splash запускал подписку в одном bloc, а экраны слушали другой.
  getIt.registerLazySingleton<ClientBloc>(
        () => ClientBloc(clientRepository: getIt<ClientRepository>()),
  );

  // ✅ QuickWorkoutPlanBloc — singleton, как ClientBloc/ScheduleBloc.
// Было registerFactory — GetIt.I<QuickWorkoutPlanBloc>() в _buildTabView
// MainScreen вызывается при каждой перерисовке (например, после возврата
// с экрана деталей плана) и создавал НОВЫЙ пустой блок в состоянии Initial,
// из-за чего список загруженных планов визуально исчезал, хотя данные
// в БД никуда не девались.
  getIt.registerLazySingleton<QuickWorkoutPlanBloc>(
        () => QuickWorkoutPlanBloc(
      getQuickWorkoutPlans: getIt<GetQuickWorkoutPlans>(),
    ),
  );

  // WorkoutPlanBloc и остальные — factory (пересоздаются при необходимости)
  getIt.registerFactory<WorkoutPlanBloc>(
        () => WorkoutPlanBloc(
      getWorkoutPlans: getIt<GetWorkoutPlans>(),
      createWorkoutPlan: getIt<CreateWorkoutPlan>(),
    ),
  );

  getIt.registerFactory<ClientWorkoutPlanBloc>(
        () => ClientWorkoutPlanBloc(
      getClientsWorkoutPlans: getIt<GetClientsWorkoutPlans>(),
      assignWorkoutPlan: getIt<AssignWorkoutPlan>(),
      updateAssignedWorkoutPlan: getIt<UpdateAssignedWorkoutPlan>(),
      deleteAssignedWorkoutPlan: getIt<DeleteAssignedWorkoutPlan>(),
    ),
  );
  getIt.registerFactory<TrainingDiaryBloc>(
        () => TrainingDiaryBloc(
      getTrainingDiaryEntries: getIt<GetTrainingDiaryEntries>(),
    ),
  );
  getIt.registerFactory<ExercisePickerBloc>(
        () => ExercisePickerBloc(getIt<ExercisesRepository>()),
  );

  // ========= RetentionBloc =========
  // factory — пересоздаётся при каждом открытии экрана
  getIt.registerFactory<RetentionBloc>(
        () => RetentionBloc(
      checkOnboarding: getIt<CheckOnboardingCompleted>(),
      getOnboarding: getIt<GetRetentionOnboarding>(),
      saveOnboarding: getIt<SaveRetentionOnboarding>(),
      checkCheckinDue: getIt<CheckCheckinDue>(),
      saveCheckin: getIt<SaveRetentionCheckin>(),
      getCheckins: getIt<GetRetentionCheckins>(),
      getSignals: getIt<GetActiveRetentionSignals>(),
      resolveSignal: getIt<ResolveRetentionSignal>(),
      getProgressSummary: getIt<GetClientProgressSummary>(),
      setRetentionEnabled: getIt<SetRetentionEnabled>(),
      getRetentionEnabled: getIt<GetRetentionEnabled>(),
      triggerOnboardingStart: getIt<TriggerOnboardingStart>(),
    ),
  );
}