import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/presentation/blocs/workout_plan_bloc.dart';
import 'package:coachsly/presentation/blocs/quick_workout_plan_bloc.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/ui/widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:coachsly/ui/widgets/universal_card.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  String selectedTab = 'Шаблоны';
  String selectedTemplateType = 'Конструктор';

  @override
  void initState() {
    super.initState();
    // Загружаем данные после того как Bloc'и точно доступны
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final user = context.read<UserProvider>().user;
    if (user != null) {
      context.read<WorkoutPlanBloc>().add(FetchWorkoutPlans(user.id));
      context.read<QuickWorkoutPlanBloc>().add(FetchQuickWorkoutPlans(user.id));
    }
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
          child: Column(
            children: [
              // Основные ChoiceChips
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Шаблоны'),
                      selected: selectedTab == 'Шаблоны',
                      onSelected: (selected) {
                        setState(() {
                          selectedTab = 'Шаблоны';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Планы клиентов'),
                      selected: selectedTab == 'Планы клиентов',
                      onSelected: (selected) {
                        setState(() {
                          selectedTab = 'Планы клиентов';
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Сегменты для типов шаблонов
              if (selectedTab == 'Шаблоны') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Конструктор'),
                        selected: selectedTemplateType == 'Конструктор',
                        onSelected: (selected) {
                          setState(() {
                            selectedTemplateType = 'Конструктор';
                          });
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Быстрая загрузка'),
                        selected: selectedTemplateType == 'Быстрая загрузка',
                        onSelected: (selected) {
                          setState(() {
                            selectedTemplateType = 'Быстрая загрузка';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Контент
              Expanded(
                child: selectedTab == 'Шаблоны'
                    ? _buildTemplatesContent()
                    : Center(
                  child: Text(
                    'Список планов клиентов появится здесь',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: selectedTab == 'Шаблоны'
          ? Container(
        margin: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: () async {
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Пожалуйста, войдите в систему')),
              );
              return;
            }

            // Ждем результат от экрана создания
            final result = await context.pushNamed<bool>('createPlan');

            // Если план был успешно создан, обновляем данные
            if (result == true) {
              _loadInitialData();
              // Показываем уведомление
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('План успешно создан!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Icon(Icons.add),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTemplatesContent() {
    if (selectedTemplateType == 'Конструктор') {
      return BlocBuilder<WorkoutPlanBloc, WorkoutPlanState>(
        builder: (context, state) {
          return _buildWorkoutPlanContent(state);
        },
      );
    } else {
      return BlocBuilder<QuickWorkoutPlanBloc, QuickWorkoutPlanState>(
        builder: (context, state) {
          return _buildQuickWorkoutPlanContent(state);
        },
      );
    }
  }

  Widget _buildWorkoutPlanContent(WorkoutPlanState state) {
    // ... остальной код без изменений (как в предыдущем ответе)
    if (state is WorkoutPlanInitial) {
      return Center(
        child: Text(
          'Тренировочные планы еще не загружены',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    } else if (state is WorkoutPlanLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    } else if (state is WorkoutPlanSuccess) {
      if (state.workoutPlans.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Нет планов из конструктора',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте свой первый план',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: state.workoutPlans.length,
        itemBuilder: (context, index) {
          final plan = state.workoutPlans[index];
          return UniversalCardV2(
            item: plan,
            onTap: () => context.pushNamed(
              'workoutPlanDetail',
              extra: plan,
            ),
          );
        },
      );
    } else if (state is WorkoutPlanError) {
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

  Widget _buildQuickWorkoutPlanContent(QuickWorkoutPlanState state) {
    // ... остальной код без изменений (как в предыдущем ответе)
    if (state is QuickWorkoutPlanInitial) {
      return Center(
        child: Text(
          'Быстрые планы еще не загружены',
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
                'Нет быстро загруженных планов',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Загрузите планы через быструю загрузку',
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