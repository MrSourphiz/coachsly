import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:coachsly/data/sources/supabase_data_source.dart';
import 'package:coachsly/data/repositories/schedule_repository_impl.dart';
import 'package:coachsly/data/repositories/workout_plan_repository_impl.dart';
import 'package:coachsly/data/repositories/auth_repository_impl.dart';
import 'package:coachsly/data/repositories/training_diary_repository_impl.dart';
import 'package:coachsly/data/repositories/client_repository_impl.dart';
import 'package:coachsly/data/repositories/notifications_repository_impl.dart';
import 'package:coachsly/data/repositories/exrcises_repository_impl.dart';

import 'package:coachsly/domain/repositories/auth_repository.dart';
import 'package:coachsly/domain/repositories/schedule_repository.dart';
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/repositories/training_diary_repository.dart';
import 'package:coachsly/domain/repositories/client_repository.dart';
import 'package:coachsly/domain/repositories/notifications_repository.dart';
import 'package:coachsly/domain/repositories/exercises_repository.dart';

import 'package:coachsly/domain/usecases/auth_user.dart';
import 'package:coachsly/domain/usecases/change_workout_plan.dart';
import 'package:coachsly/domain/usecases/check_auth.dart';
import 'package:coachsly/domain/usecases/check_auth_status.dart';
import 'package:coachsly/domain/usecases/login_user.dart';
import 'package:coachsly/domain/usecases/logout_user.dart';
import 'package:coachsly/domain/usecases/register_user.dart';
import 'package:coachsly/domain/usecases/get_schedules.dart';
import 'package:coachsly/domain/usecases/book_session.dart';
import 'package:coachsly/domain/usecases/get_trainer_clients.dart';
import 'package:coachsly/domain/usecases/get_workout_plans.dart';
import 'package:coachsly/domain/usecases/get_quick_workout_plans.dart';
import 'package:coachsly/domain/usecases/get_clients_workout_plans.dart';
import 'package:coachsly/domain/usecases/assign_workout_plan.dart';
import 'package:coachsly/domain/usecases/update_assigned_workout_plan.dart';
import 'package:coachsly/domain/usecases/delete_assigned_workout_plan.dart';
import 'package:coachsly/domain/usecases/create_workout_plan.dart';
import 'package:coachsly/domain/usecases/get_training_diary_entries.dart';

import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:coachsly/presentation/blocs/schedule_bloc.dart';
import 'package:coachsly/presentation/blocs/workout_plan_bloc.dart';
import 'package:coachsly/presentation/blocs/quick_workout_plan_bloc.dart';
import 'package:coachsly/presentation/blocs/client_workout_plan_bloc.dart';
import 'package:coachsly/presentation/blocs/training_diary_bloc.dart';
import 'package:coachsly/presentation/blocs/client_bloc.dart';
import 'package:coachsly/presentation/blocs/exercises_bloc.dart';

import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/presentation/providers/notifications_provider.dart';

// Добавленные импорты для генератора тренировок
import 'package:coachsly/core/network/dio_client.dart';
import 'package:coachsly/data/sources/workout_generator_remote_data_source.dart';
import 'package:coachsly/data/repositories/workout_generator_repository_impl.dart';
import 'package:coachsly/domain/repositories/workout_generator_repository.dart';
import 'package:coachsly/domain/usecases/generate_workout_plan.dart';
import 'package:coachsly/presentation/blocs/workout_generator_bloc.dart';

final getIt = GetIt.instance;

void setupDI() {
  // ========= Регистрация UserProvider =========
  getIt.registerSingleton<UserProvider>(UserProvider());

  // ========= Регистрация SupabaseClient =========
  getIt.registerSingleton<SupabaseClient>(
    Supabase.instance.client,
  );

  // ========= Регистрация DioClient =========
  getIt.registerLazySingleton<DioClient>(() => DioClient());

  // ========= Регистрация SupabaseDataSource с передачей SupabaseClient =========
  getIt.registerLazySingleton<SupabaseDataSource>(
        () => SupabaseDataSource(getIt<SupabaseClient>()),
  );

  // ========== РЕГИСТРАЦИЯ КОМПОНЕНТОВ ГЕНЕРАТОРА ТРЕНИРОВОК ==========
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

  getIt.registerLazySingleton(() => GenerateWorkoutPlan(
    getIt<WorkoutGeneratorRepository>(),
  ));

  getIt.registerFactory(() => WorkoutGeneratorBloc(
    generateWorkoutPlan: getIt<GenerateWorkoutPlan>(),
  ));
  // ===================================================================

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
  getIt.registerLazySingleton<TrainingDiaryRepository>(
        () => TrainingDiaryRepositoryImpl(getIt<SupabaseDataSource>()),
  );
  getIt.registerLazySingleton<ClientRepository>(
        () => ClientRepositoryImpl(getIt<SupabaseClient>()),
  );

  // ========= Use Cases =========
  getIt.registerLazySingleton(() => AuthenticateUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => ChangeWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => CheckAuth(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => CheckAuthStatus(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LoginUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => RegisterUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => GetSchedules(getIt<ScheduleRepository>()));
  getIt.registerLazySingleton(() => GetTrainerClients(getIt<ClientRepository>()));
  getIt.registerLazySingleton(() => BookSession(getIt<ScheduleRepository>()));
  getIt.registerLazySingleton(() => GetWorkoutPlans(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => GetQuickWorkoutPlans(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => GetClientsWorkoutPlans(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => AssignWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => UpdateAssignedWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => DeleteAssignedWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => CreateWorkoutPlan(getIt<WorkoutPlanRepository>()));
  getIt.registerLazySingleton(() => GetTrainingDiaryEntries(getIt<TrainingDiaryRepository>()));


  // ========= PROVIDERS =========
  getIt.registerFactoryParam<NotificationsProvider, String, void>(
        (trainerId, _) => NotificationsProvider(
      trainerId: trainerId,
      repository: getIt<NotificationsRepository>(),
    ),
  );

  // ========= BLoC =========
  // Регистрация AuthBloc
  getIt.registerFactory<AuthBloc>(
        () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );

  // Регистрация ScheduleBloc
  getIt.registerFactory<ScheduleBloc>(
        () => ScheduleBloc(
      getSchedules: GetSchedules(getIt<ScheduleRepository>()),
      bookSession: BookSession(getIt<ScheduleRepository>()),
    ),
  );

  // Регистрация WorkoutPlanBloc
  getIt.registerFactory<WorkoutPlanBloc>(
        () => WorkoutPlanBloc(
      getWorkoutPlans: GetWorkoutPlans(getIt<WorkoutPlanRepository>()),
      createWorkoutPlan: CreateWorkoutPlan(getIt<WorkoutPlanRepository>()),
    ),
  );

  // Регистрация QuickWorkoutPlanBloc
  getIt.registerFactory<QuickWorkoutPlanBloc>(
        () => QuickWorkoutPlanBloc(
          getQuickWorkoutPlans: GetQuickWorkoutPlans(getIt<WorkoutPlanRepository>()),
    ),
  );

  // Регистрация ClientWorkoutPlanBloc
  getIt.registerFactory<ClientWorkoutPlanBloc>(
        () => ClientWorkoutPlanBloc(
          getClientsWorkoutPlans: GetClientsWorkoutPlans(getIt<WorkoutPlanRepository>()),
          assignWorkoutPlan: AssignWorkoutPlan(getIt<WorkoutPlanRepository>()),
          updateAssignedWorkoutPlan: UpdateAssignedWorkoutPlan(getIt<WorkoutPlanRepository>()),
          deleteAssignedWorkoutPlan: DeleteAssignedWorkoutPlan(getIt<WorkoutPlanRepository>()),
    ),
  );

  getIt.registerFactory<TrainingDiaryBloc>(
          () => TrainingDiaryBloc(
      getTrainingDiaryEntries: GetTrainingDiaryEntries(getIt<TrainingDiaryRepository>()),
  ));

  getIt.registerFactory<ExercisePickerBloc>(
        () => ExercisePickerBloc(getIt<ExercisesRepository>()),
  );

  // Регистрация ClientBloc
  getIt.registerFactory<ClientBloc>(
        () => ClientBloc(clientRepository: getIt<ClientRepository>()),
  );
}