import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formeo/presentation/blocs/quick_workout_plan_bloc.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/ui/widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/ui/widgets/universal_card.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  @override
  void initState() {
    super.initState();
    // Подписываемся один раз после того как Bloc точно доступен.
    // SubscribeQuickWorkoutPlans — Realtime-подписка (по аналогии с
    // ClientBloc/ScheduleBloc): список обновляется сам при создании
    // нового плана, повторный вызов не нужен.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        context.read<QuickWorkoutPlanBloc>().add(SubscribeQuickWorkoutPlans(user.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double navBarHeight = 70.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final user = context.read<UserProvider>().user;

    if (user == null) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: navBarHeight + bottomPadding + 20.0),
            child: Center(
              child: Text(
                'Пользователь не авторизован',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: 'Тренировочные планы',
        trainerId: user.id,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: navBarHeight + bottomPadding + 20.0),
          child: BlocBuilder<QuickWorkoutPlanBloc, QuickWorkoutPlanState>(
            buildWhen: (previous, current) =>
            current is! QuickWorkoutPlanLoading || previous is! QuickWorkoutPlanSuccess,
            builder: (context, state) {
              return _buildQuickWorkoutPlanContent(state);
            },
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: () async {
            // Список обновится сам через Realtime-подписку — явный
            // ре-фетч после создания плана больше не нужен.
            final result = await context.pushNamed<bool>('createPlan');

            if (result == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('План успешно создан!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          backgroundColor: Theme.of(context).colorScheme.secondary,
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildQuickWorkoutPlanContent(QuickWorkoutPlanState state) {
    if (state is QuickWorkoutPlanInitial) {
      return Center(
        child: Text(
          'Тренировочные планы ещё не загружены',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    } else if (state is QuickWorkoutPlanLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    } else if (state is QuickWorkoutPlanSuccess) {
      if (state.quickWorkoutPlans.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flash_on, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Нет загруженных планов',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Загрузите свою первую программу',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: state.quickWorkoutPlans.length,
        itemBuilder: (context, index) {
          final plan = state.quickWorkoutPlans[index];
          return UniversalCardV2(
            item: plan,
            onTap: () => context.pushNamed(
              'quickWorkoutPlanDetail',
              extra: plan,
            ),
          );
        },
      );
    } else if (state is QuickWorkoutPlanError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
