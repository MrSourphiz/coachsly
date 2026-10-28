import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/blocs/quick_workout_plan_bloc.dart';
import 'package:formeo/presentation/screens/clients_screen.dart';
import 'package:formeo/presentation/screens/schedule_screen.dart';
import 'package:formeo/presentation/screens/dashboard_screen.dart';
import 'package:formeo/presentation/screens/settings_screen.dart';
import 'package:formeo/presentation/screens/workout_plan_screen.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) context.read<AuthBloc>().add(CheckAuthStatusEvent());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;

        if (user == null) {
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

        return _buildTabView(context, user);
      },
    );
  }

  Widget _buildTabView(BuildContext context, User user) {
    final showWorkouts = user.isPro;
    // Позиция вкладки "Тренировки" в списке — нужна и для screens, и для подсветки SVG-иконки.
    final workoutsTabIndex = showWorkouts ? 2 : -1;

    final screens = [
      BlocProvider.value(
        value: GetIt.I<ScheduleBloc>(),
        child: const TodayScheduleScreen(),
      ),
      BlocProvider.value(
        value: GetIt.I<ScheduleBloc>(),
        child: const ScheduleScreen(),
      ),
      if (showWorkouts)
        BlocProvider.value(
          value: GetIt.I<QuickWorkoutPlanBloc>(),
          child: const WorkoutPlanScreen(),
        ),
      BlocProvider.value(
        value: GetIt.I<ClientBloc>(),
        child: const ClientsScreen(),
      ),
      BlocProvider.value(
        value: GetIt.I<ClientBloc>(),
        child: TrainerSettingsScreen(),
      ),
    ];

    return PersistentTabView(
      context,
      controller: _controller,
      screens: screens,
      items: _buildNavBarItems(context, workoutsTabIndex),
      confineToSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      hideNavigationBarWhenKeyboardAppears: true,
      margin: const EdgeInsets.all(0.0),
      bottomScreenMargin: 0.0,
      navBarHeight: 70.0,
      onItemSelected: (index) async {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true && !kIsWeb) {
          await Vibration.vibrate(duration: 50);
        }
        setState(() => _controller.index = index);
      },
      decoration: NavBarDecoration(
        colorBehindNavBar: Theme.of(context).scaffoldBackgroundColor,
      ),
      navBarStyle: NavBarStyle.style10,
    );
  }

  List<PersistentBottomNavBarItem> _buildNavBarItems(BuildContext context, int workoutsTabIndex) {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.fact_check_rounded),
        title: 'Сегодня',
        activeColorPrimary: Theme.of(context).colorScheme.secondary,
        activeColorSecondary: Theme.of(context).colorScheme.surface,
        inactiveColorPrimary: Theme.of(context).colorScheme.outline,
        iconSize: 30.0,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.calendar_today),
        title: 'Расписание',
        activeColorPrimary: Theme.of(context).colorScheme.secondary,
        activeColorSecondary: Theme.of(context).colorScheme.surface,
        inactiveColorPrimary: Theme.of(context).colorScheme.outline,
        iconSize: 30.0,
      ),
      if (workoutsTabIndex != -1)
        PersistentBottomNavBarItem(
          icon: SvgPicture.asset(
            'assets/images/icon-kettlebell.svg',
            width: 28,
            height: 28,
            colorFilter: ColorFilter.mode(
              _controller.index == workoutsTabIndex
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
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.group),
        title: 'Мои клиенты',
        activeColorPrimary: Theme.of(context).colorScheme.secondary,
        activeColorSecondary: Theme.of(context).colorScheme.surface,
        inactiveColorPrimary: Theme.of(context).colorScheme.outline,
        iconSize: 30.0,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.settings),
        title: 'Настройки',
        activeColorPrimary: Theme.of(context).colorScheme.secondary,
        activeColorSecondary: Theme.of(context).colorScheme.surface,
        inactiveColorPrimary: Theme.of(context).colorScheme.outline,
        iconSize: 30.0,
      ),
    ];
  }
}
