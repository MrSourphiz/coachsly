import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/presentation/blocs/schedule_bloc.dart';
import 'package:coachsly/presentation/screens/clients_screen.dart';
import 'package:coachsly/presentation/screens/schedule_screen.dart';
import 'package:coachsly/presentation/screens/dashboard_screen.dart';
import 'package:coachsly/presentation/blocs/workout_plan_bloc.dart';
import 'package:coachsly/presentation/screens/workout_plan_screen.dart';
import 'package:coachsly/presentation/blocs/training_diary_bloc.dart';
import 'package:coachsly/presentation/screens/training_diary_screen.dart';
import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:coachsly/presentation/blocs/client_bloc.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: 0);
    print('MainScreen: initState');
    // Проверяем статус аутентификации при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(CheckAuthStatusEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    print('MainScreen rendered');
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        print('MainScreen: user = ${user?.email ?? 'null'}, role = ${user?.role ?? 'null'}');

        if (user == null) {
          print('MainScreen: user is null, waiting for CheckAuthStatus');
          return Scaffold(
            body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
            ),
          );
        }

        final List<Widget> _screensTrainer = [
          /*
          BlocProvider(
            create: (context) => GetIt.I<WorkoutPlanBloc>()..add(FetchWorkoutPlans(user.id)),
            child: WorkoutPlanScreen(),
          ),

           */
          BlocProvider(
            create: (context) => GetIt.I<ScheduleBloc>()..add(FetchSchedules(user.id)),
            child: ScheduleScreen(),
          ),
          BlocProvider(
            create: (context) => GetIt.I<ScheduleBloc>()..add(FetchSchedules(user.id)),
            child: TodayScheduleScreen(),
          ),
          BlocProvider(
            create: (context) => GetIt.I<ClientBloc>()..add(FetchClients(user.id)),
            child: ClientsScreen(),
          ),
          BlocProvider(
            create: (context) => GetIt.I<ClientBloc>()..add(FetchClients(user.id)),
            child: ClientsScreen(),
          ),
        ];

        List<PersistentBottomNavBarItem> buildNavBarItems(int selectedIndex) {
          return [
            /*
            PersistentBottomNavBarItem(
              icon: SvgPicture.asset(
                'assets/images/icon-kettlebell.svg',
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(
                  selectedIndex == 0
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).colorScheme.outline,
                  BlendMode.srcIn,
                ),
              ),
              title: 'Тренировки',
              activeColorPrimary: Theme.of(context).colorScheme.secondary,
              activeColorSecondary: Theme.of(context).colorScheme.surface,
              inactiveColorPrimary: Theme.of(context).colorScheme.outline,
            ),

             */
            PersistentBottomNavBarItem(
              icon: const Icon(Icons.calendar_today),
              title: 'Расписание',
              activeColorPrimary: Theme.of(context).colorScheme.secondary,
              activeColorSecondary: Theme.of(context).colorScheme.surface,
              inactiveColorPrimary: Theme.of(context).colorScheme.outline,
              iconSize: 30.0, // Размер иконки
            ),
            PersistentBottomNavBarItem(
              icon: const Icon(Icons.fact_check_rounded),
              title: 'Сегодня',
              activeColorPrimary: Theme.of(context).colorScheme.secondary,
              activeColorSecondary: Theme.of(context).colorScheme.surface,
              inactiveColorPrimary: Theme.of(context).colorScheme.outline,
              iconSize: 30.0, // Размер иконки
            ),
            PersistentBottomNavBarItem(
              icon: const Icon(Icons.group),
              title: 'Мои клиенты',
              activeColorPrimary: Theme.of(context).colorScheme.secondary,
              activeColorSecondary: Theme.of(context).colorScheme.surface,
              inactiveColorPrimary: Theme.of(context).colorScheme.outline,
              iconSize: 30.0, // Размер иконки
            ),
            PersistentBottomNavBarItem(
              icon: const Icon(Icons.settings),
              title: 'Настройки',
              activeColorPrimary: Theme.of(context).colorScheme.secondary,
              activeColorSecondary: Theme.of(context).colorScheme.surface,
              inactiveColorPrimary: Theme.of(context).colorScheme.outline,
              iconSize: 30.0, // Размер иконки
            ),
          ];
        }

    //    final List<PersistentBottomNavBarItem> _navBarsItems = [
    //        PersistentBottomNavBarItem(
    //          icon: const Icon(Icons.fitness_center),
    //          title: 'Тренировки',
    //          activeColorPrimary: Theme.of(context).colorScheme.secondary,
    //          activeColorSecondary: Theme.of(context).colorScheme.surface,
    //          inactiveColorPrimary: Theme.of(context).colorScheme.outline,
    //          iconSize: 30.0, // Размер иконки
    //        ),
    //        PersistentBottomNavBarItem(
    //          icon: const Icon(Icons.calendar_today),
    //          title: 'Расписание',
    //          activeColorPrimary: Theme.of(context).colorScheme.secondary,
    //          activeColorSecondary: Theme.of(context).colorScheme.surface,
    //          inactiveColorPrimary: Theme.of(context).colorScheme.outline,
    //          iconSize: 30.0, // Размер иконки
    //        ),
    //        PersistentBottomNavBarItem(
    //          icon: const Icon(Icons.group),
    //          title: 'Мои клиенты',
    //          activeColorPrimary: Theme.of(context).colorScheme.secondary,
    //          activeColorSecondary: Theme.of(context).colorScheme.surface,
    //          inactiveColorPrimary: Theme.of(context).colorScheme.outline,
    //          iconSize: 30.0, // Размер иконки
    //        ),
    //        PersistentBottomNavBarItem(
    //          icon: const Icon(Icons.settings),
    //          title: 'Настройки',
    //          activeColorPrimary: Theme.of(context).colorScheme.secondary,
    //          activeColorSecondary: Theme.of(context).colorScheme.surface,
    //          inactiveColorPrimary: Theme.of(context).colorScheme.outline,
    //          iconSize: 30.0, // Размер иконки
    //        ),
    //      ];


        return PersistentTabView(
          context,
          controller: _controller,
          screens: _screensTrainer,
          items: buildNavBarItems(_controller.index),
          confineToSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.primary,
          handleAndroidBackButtonPress: true,
          resizeToAvoidBottomInset: true,
          stateManagement: true,
          hideNavigationBarWhenKeyboardAppears: true,
          margin: const EdgeInsets.all(0.0),
          bottomScreenMargin: 0.0,
          navBarHeight: 70.0, // Увеличиваем высоту для размещения текста
          onItemSelected: (index) async {
            // Проверяем, поддерживается ли вибрация
            bool? hasVibrator = await Vibration.hasVibrator();
            if (hasVibrator == true && !kIsWeb) {
              // Короткая вибрация (50 мс)
              await Vibration.vibrate(duration: 50);
            }

            setState(() {
              _controller.index = index; // Обновляем индекс при выборе вкладки
            });
          },
          decoration: NavBarDecoration(
            //borderRadius: BorderRadius.circular(10.0),
            colorBehindNavBar: Theme.of(context).scaffoldBackgroundColor,
          ),
          navBarStyle: NavBarStyle.style10, // Устанавливаем стиль Style10
        );
      },
    );
  }
}
