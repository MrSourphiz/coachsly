import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:coachsly/presentation/blocs/schedule_bloc.dart';
import 'package:coachsly/presentation/blocs/workout_plan_bloc.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, authState) {
          print('LoadingScreen AuthBloc state: $authState');
          if (authState is AuthUnauthenticated) {
            print('Перенаправление на /auth из LoadingScreen');
            context.go('/auth');
          }
        },
        builder: (context, authState) {
          print('LoadingScreen AuthBloc builder: $authState');
          if (authState is! AuthAuthenticated) {
            return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.secondary, // Бордовый
                  ),
                ),
            );
          }

          final userId = authState.user.id;

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => GetIt.I<ScheduleBloc>()
                  ..add(FetchSchedules(userId)),
              ),
              BlocProvider(
                create: (context) => GetIt.I<WorkoutPlanBloc>(),
              ),
            ],
            child: BlocListener<ScheduleBloc, ScheduleState>(
              listener: (context, scheduleState) {
                print('ScheduleBloc state: $scheduleState');
                if (scheduleState is ScheduleSuccess) {
                  context.read<WorkoutPlanBloc>().add(FetchWorkoutPlans(userId));
                } else if (scheduleState is ScheduleError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(scheduleState.message)),
                  );
                }
              },
              child: BlocListener<WorkoutPlanBloc, WorkoutPlanState>(
                listener: (context, workoutPlanState) {
                  print('WorkoutPlanBloc state: $workoutPlanState');
                  if (workoutPlanState is WorkoutPlanSuccess) {
                    print('Перенаправление на /main из LoadingScreen');
                    context.go('/main');
                  } else if (workoutPlanState is WorkoutPlanError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(workoutPlanState.message)),
                    );
                  }
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                          'Загрузка данных...',
                          style: Theme.of(context).textTheme.bodyLarge,
                      ),
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