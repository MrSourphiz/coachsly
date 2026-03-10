import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/presentation/blocs/workout_generator_bloc.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';

class WorkoutGeneratorScreen extends StatelessWidget {
  const WorkoutGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Оберните весь экран в BlocProvider
    return BlocProvider(
      create: (context) => GetIt.instance<WorkoutGeneratorBloc>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Генератор тренировок')),
        body: _buildBody(context),
      ),
    );
  }


  @override
  Widget _buildBody(BuildContext context) {
    return BlocConsumer<WorkoutGeneratorBloc, WorkoutGeneratorState>(
        listener: (context, state) {
          if (state is WorkoutGeneratorFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        builder: (context, state) {
          if (state is WorkoutGeneratorLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WorkoutGeneratorSuccess) {
            return _buildPlanView(state.plan);
          }

          return _buildInitialView(context);
        },
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => _generatePlan(context),
        child: const Text('Сгенерировать план тренировок'),
      ),
    );
  }

  Widget _buildPlanView(WorkoutPlan plan) {
    return ListView.builder(
      itemCount: plan.days.length,
      itemBuilder: (context, index) {
        final day = plan.days[index];
        return ExpansionTile(
          title: Text('День ${day.dayOfWeek}'),
          subtitle: Text(day.description),
          children: day.items.map((item) {
            return ListTile(
              title: Text(_getItemTypeTitle(item.type)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.exercises.map((ex) {
                  return Text('${ex.name}: ${ex.workSets}x${ex.reps}');
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _getItemTypeTitle(WorkoutItemType type) {
    switch (type) {
      case WorkoutItemType.single: return 'Одиночное упражнение';
      case WorkoutItemType.superset: return 'Суперсет';
      case WorkoutItemType.triset: return 'Трисет';
      case WorkoutItemType.circuit: return 'Круговая тренировка';
      default: return 'Упражнение';
    }
  }

  void _generatePlan(BuildContext context) {
    // Пример данных - замените реальными данными из вашего приложения
    final userData = {
      'age': 32,
      'height': 180,
      'weight': 98,
      'sport_experience': 'Никогда не занимался спортом, сидячий образ жизни',
      'goals': 'Сжечь жир и набрать мышцы',
      'preferences': 'Только занятия дома',
      'health_restrictions': 'Травма колена, боли в пояснице',
    };

    final programParams = {
      'programType': 'strength',
      'duration': 6,
      'schedule': '4 дня в неделю',
    };

    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    context.read<WorkoutGeneratorBloc>().add(
      GenerateWorkoutPlanEvent(
        userData: userData,
        programParams: programParams,
        accessToken: accessToken,
      ),
    );
  }

  void _savePlan(BuildContext context, WorkoutPlan plan) {
    // Реализуйте сохранение плана в Supabase
    // Можно добавить BLoC для сохранения или вызвать напрямую
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('План сохранен!')),
    );
  }
}