import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

// настройки DI
import 'di.dart';

// настройки router
import 'router.dart';

//constants
import 'package:coachsly/core/constants/colors.dart';

// provider
import 'package:coachsly/presentation/providers/user_provider.dart';

// auth
import 'package:coachsly/domain/repositories/auth_repository.dart';

// schedules
import 'package:coachsly/domain/repositories/schedule_repository.dart';

// workout plans
import 'package:coachsly/domain/repositories/workout_plan_repository.dart';
import 'package:coachsly/domain/repositories/workout_generator_repository.dart';

// notifications
import 'package:coachsly/domain/repositories/notifications_repository.dart';

// training diary
import 'package:coachsly/domain/repositories/training_diary_repository.dart';

// client
import 'package:coachsly/domain/repositories/client_repository.dart';

//exercises
import 'package:coachsly/domain/repositories/exercises_repository.dart';

// blocs
import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:coachsly/presentation/blocs/workout_plan_bloc.dart';
import 'package:coachsly/presentation/blocs/quick_workout_plan_bloc.dart';
import 'package:coachsly/presentation/blocs/client_workout_plan_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  setupDI();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        ChangeNotifierProvider<UserProvider>(
          create: (_) => GetIt.I<UserProvider>(),
        ),
        RepositoryProvider<AuthRepository>(
          create: (context) => GetIt.I<AuthRepository>(),
        ),
        RepositoryProvider<ScheduleRepository>(
          create: (context) => GetIt.I<ScheduleRepository>(),
        ),
        RepositoryProvider<WorkoutPlanRepository>(
          create: (context) => GetIt.I<WorkoutPlanRepository>(),
        ),
        RepositoryProvider<WorkoutGeneratorRepository>(
          create: (context) => GetIt.I<WorkoutGeneratorRepository>(),
        ),
        RepositoryProvider<TrainingDiaryRepository>(
          create: (context) => GetIt.I<TrainingDiaryRepository>(),
        ),
        RepositoryProvider<ClientRepository>(
          create: (context) => GetIt.I<ClientRepository>(),
        ),
        RepositoryProvider<NotificationsRepository>(
          create: (_) => GetIt.I<NotificationsRepository>(),
        ),
        RepositoryProvider<ExercisesRepository>(
          create: (_) => GetIt.I<ExercisesRepository>(),
        ),
        BlocProvider<WorkoutPlanBloc>(create: (context) => getIt<WorkoutPlanBloc>()),
        BlocProvider<QuickWorkoutPlanBloc>(create: (context) => getIt<QuickWorkoutPlanBloc>()),
        BlocProvider<ClientWorkoutPlanBloc>(create: (context) => getIt<ClientWorkoutPlanBloc>()),
      ],
      child: BlocProvider(
        create: (context) => GetIt.I<AuthBloc>()..add(CheckAuthStatusEvent()),
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
              accentColor: AppColors.colorDarkRed, // Бордовый для акцентов
              backgroundColor: AppColors.colorBlue, // Тёмно-синий
            ).copyWith(
                primary: AppColors.colorLightBlue,
                secondary: AppColors.colorDarkRed, // Бордовый
                surface: AppColors.colorWhite, // Мягкий белый
                onSurface: AppColors.colorLightBlue,
                outline: AppColors.colorGrey,
            ),
            scaffoldBackgroundColor: AppColors.colorBlue,
            primarySwatch: customSwatch,
            fontFamily: 'Roboto',
            iconTheme: IconThemeData(color: AppColors.colorDarkRed),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.colorBlue,
              foregroundColor: AppColors.colorWhite,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorDarkRed, // Бордовый
                foregroundColor: AppColors.colorWhite, // Мягкий белый
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.colorDarkRed, // Бордовый
                foregroundColor: AppColors.colorWhite, // Мягкий белый
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color:AppColors.colorWhite),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: AppColors.colorDarkRed, // Бордовый
              foregroundColor: AppColors.colorWhite, // Мягкий белый
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: AppColors.colorWhite, // Мягкий белый
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.colorGrey), // Серый
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.colorGrey), // Серый
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.colorDarkRed, width: 2), // Бордовый
              ),
              labelStyle: TextStyle(color: AppColors.colorGrey), // Серый
              hintStyle: TextStyle(color: AppColors.colorGrey), // Серый
            ),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.colorWhite, // Мягкий белый
              ),
              headlineMedium: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.colorWhite, // Мягкий белый
              ),
              bodyLarge: TextStyle(
                fontSize: 16,
                color: AppColors.colorWhite, // Мягкий белый
              ),
              bodyMedium: TextStyle(
                fontSize: 14,
                color: AppColors.colorWhite, // Мягкий белый
              ),
              bodySmall: TextStyle(
                fontSize: 12,
                color: AppColors.colorGrey, // Серый
              ),
              labelMedium: TextStyle(
                fontSize: 14,
                color: AppColors.colorBlue, // Мягкий белый
              ),
            ),
            dialogTheme: DialogTheme(
              backgroundColor: AppColors.colorWhite, // Мягкий белый
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              titleTextStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.colorBlue, // Тёмно-синий
              ),
              contentTextStyle: const TextStyle(
                fontSize: 16,
                color: AppColors.colorBlue, // Тёмно-синий
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.colorDarkRed, // Бордовый
              contentTextStyle: const TextStyle(color: AppColors.colorWhite), // Мягкий белый
              actionTextColor: AppColors.colorWhite, // Мягкий белый
            ),
            cardTheme: CardTheme(
              color: AppColors.colorWhite, // Мягкий белый
              shadowColor: AppColors.colorGrey, // Серый
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            listTileTheme: ListTileThemeData(
              tileColor: AppColors.colorWhite, // Мягкий белый
              textColor: AppColors.colorBlue, // Тёмно-синий
              iconColor: AppColors.colorDarkRed, // Бордовый
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          routerConfig: router,
        ),
      ),
    );
  }
}