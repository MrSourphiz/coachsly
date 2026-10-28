import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// настройки DI
import 'di.dart';

// настройки router
import 'router.dart';

// splash
import 'splash_wrapper.dart';

//constants
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/core/constants/supabase_constants.dart';

// providers
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/presentation/providers/splash_progress_provider.dart';

// repositories
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/repositories/schedule_repository.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/domain/repositories/workout_generator_repository.dart';
import 'package:formeo/domain/repositories/notifications_repository.dart';
import 'package:formeo/domain/repositories/training_diary_repository.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/domain/repositories/exercises_repository.dart';

// providers
import 'package:formeo/presentation/providers/notifications_provider.dart';

// blocs
import 'package:formeo/presentation/blocs/auth_bloc.dart';

// push notifications
import 'package:formeo/core/service/push_notification_service.dart';

import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();

  // Проверяем что ключи переданы через --dart-define
  SupabaseConstants.assertConfigured();

  // При первом запуске после установки/переустановки чистим Secure Storage.
  // FlutterSecureStorage на Android сохраняется между переустановками
  // (хранится в Keystore), поэтому без этой очистки кэш роли от предыдущей
  // установки попадает в checkAuthStatus и пользователь видит онбординг
  // вместо экрана входа.
  final prefs = await SharedPreferences.getInstance();
  final isFirstRun = prefs.getBool('app_installed') ?? true;
  if (isFirstRun) {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    await prefs.setBool('app_installed', false);
  }

  // Firebase и Supabase инициализируем параллельно
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ),
  ]);

  // Фоновый обработчик пушей
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  setupDI();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Создаём router ОДИН раз после setupDI() — не пересоздаём при rebuild.
  // createRouter() безопасен здесь: setupDI() уже вызван в main().
  late final GoRouter _router = createRouter();

  static const MaterialColor customSwatch = MaterialColor(
    0xFF172554,
    {
      50: Color(0xFFE8EAF6),
      100: Color(0xFFC5CAE9),
      200: Color(0xFF9FA8DA),
      300: Color(0xFF7986CB),
      400: Color(0xFF5C6BC0),
      500: Color(0xFF3F51B5),
      600: Color(0xFF3949AB),
      700: Color(0xFF303F9F),
      800: Color(0xFF283593),
      900: Color(0xFF1A237E),
    },
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProgressProvider>(
          create: (_) => SplashProgressProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => GetIt.I<UserProvider>(),
        ),
        RepositoryProvider<AuthRepository>(
          create: (_) => GetIt.I<AuthRepository>(),
        ),
        RepositoryProvider<ScheduleRepository>(
          create: (_) => GetIt.I<ScheduleRepository>(),
        ),
        RepositoryProvider<WorkoutPlanRepository>(
          create: (_) => GetIt.I<WorkoutPlanRepository>(),
        ),
        RepositoryProvider<WorkoutGeneratorRepository>(
          create: (_) => GetIt.I<WorkoutGeneratorRepository>(),
        ),
        RepositoryProvider<TrainingDiaryRepository>(
          create: (_) => GetIt.I<TrainingDiaryRepository>(),
        ),
        RepositoryProvider<ClientRepository>(
          create: (_) => GetIt.I<ClientRepository>(),
        ),
        RepositoryProvider<NotificationsRepository>(
          create: (_) => GetIt.I<NotificationsRepository>(),
        ),
        // NotificationsProvider зависит от UserProvider — создаётся автоматически
        // когда пользователь авторизуется, и пересоздаётся при смене аккаунта.
        // Размещён здесь (выше MaterialApp.router) — доступен на ВСЕХ роутах.
        ChangeNotifierProxyProvider<UserProvider, NotificationsProvider?>(
          create: (_) => null,
          update: (_, userProvider, previous) {
            final userId = userProvider.user?.id;

            // FIX #2: если userId временно null (Supabase обновляет токен,
            // перестройка дерева при resume) — НЕ уничтожаем провайдер.
            // Возвращаем предыдущий экземпляр чтобы подписка и данные сохранились.
            // Без этого фикса: previous.dispose() → _sub.cancel() → список пуст.
            if (userId == null) return previous;

            // Переиспользуем существующий если userId не изменился
            if (previous != null && previous.trainerId == userId) {
              return previous;
            }

            // Новый пользователь (смена аккаунта) — создаём новый провайдер
            return NotificationsProvider(
              trainerId: userId,
              repository: GetIt.I<NotificationsRepository>(),
            );
          },
        ),
        RepositoryProvider<ExercisesRepository>(
          create: (_) => GetIt.I<ExercisesRepository>(),
        ),
        // BlocProvider<WorkoutPlanBloc>(create: (_) => getIt<WorkoutPlanBloc>()), // временно отключено
        // BlocProvider<QuickWorkoutPlanBloc>(create: (_) => getIt<QuickWorkoutPlanBloc>()), // временно отключено
        // BlocProvider<ClientWorkoutPlanBloc>(create: (_) => getIt<ClientWorkoutPlanBloc>()), // временно отключено
      ],
      child: BlocProvider.value(
        value: GetIt.I<AuthBloc>()..add(CheckAuthStatusEvent()),
        child: Builder(
          builder: (context) => SplashWrapper(
            child: MaterialApp.router(
              locale: const Locale('ru', 'RU'),
              supportedLocales: const [
                Locale('ru', 'RU'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                colorScheme: ColorScheme.fromSwatch(
                  primarySwatch: customSwatch,
                  accentColor: AppColors.colorDarkRed,
                  backgroundColor: AppColors.colorBlue,
                ).copyWith(
                  primary: AppColors.colorLightBlue,
                  secondary: AppColors.colorDarkRed,
                  surface: AppColors.colorWhite,
                  onSurface: AppColors.colorBlue,
                  outline: AppColors.colorGrey,
                ),
                scaffoldBackgroundColor: AppColors.colorBlue,
                primarySwatch: customSwatch,
                fontFamily: 'Roboto',
                iconTheme: const IconThemeData(color: AppColors.colorDarkRed),
                appBarTheme: const AppBarTheme(
                  backgroundColor: AppColors.colorBlue,
                  foregroundColor: AppColors.colorWhite,
                  elevation: 0,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorDarkRed,
                    foregroundColor: AppColors.colorWhite,
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.colorDarkRed,
                    foregroundColor: AppColors.colorWhite,
                    textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.colorWhite),
                  ),
                ),
                floatingActionButtonTheme:
                const FloatingActionButtonThemeData(
                  backgroundColor: AppColors.colorDarkRed,
                  foregroundColor: AppColors.colorWhite,
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  filled: true,
                  fillColor: AppColors.colorWhite,
                  floatingLabelStyle: TextStyle(
                    color: AppColors.colorDarkRed,
                    backgroundColor: AppColors.colorBlue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.colorGrey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.colorGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide:
                    BorderSide(color: AppColors.colorDarkRed, width: 2),
                  ),
                  labelStyle: TextStyle(color: AppColors.colorBlue),
                  hintStyle: TextStyle(color: AppColors.colorGrey),
                ),
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: AppColors.colorDarkRed,
                ),
                textTheme: const TextTheme(
                  headlineLarge: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorWhite,
                  ),
                  headlineMedium: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite,
                  ),
                  bodyLarge: TextStyle(
                    fontSize: 16,
                    color: AppColors.colorBlue,
                  ),
                  bodyMedium: TextStyle(
                    fontSize: 14,
                    color: AppColors.colorWhite,
                  ),
                  bodySmall: TextStyle(
                    fontSize: 12,
                    color: AppColors.colorGrey,
                  ),
                  labelMedium: TextStyle(
                    fontSize: 14,
                    color: AppColors.colorBlue,
                  ),
                ),
                dialogTheme: DialogTheme(
                  backgroundColor: AppColors.colorWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  titleTextStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorBlue,
                  ),
                  contentTextStyle: const TextStyle(
                    fontSize: 16,
                    color: AppColors.colorBlue,
                  ),
                ),
                snackBarTheme: const SnackBarThemeData(
                  backgroundColor: AppColors.colorDarkRed,
                  contentTextStyle: TextStyle(color: AppColors.colorWhite),
                  actionTextColor: AppColors.colorWhite,
                ),
                cardTheme: CardTheme(
                  color: AppColors.colorWhite,
                  shadowColor: AppColors.colorGrey,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                listTileTheme: ListTileThemeData(
                  tileColor: AppColors.colorWhite,
                  textColor: AppColors.colorBlue,
                  iconColor: AppColors.colorDarkRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              routerConfig: _router,
            ),
          ),
        ),
      ),
    );
  }
}
