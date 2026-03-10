import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/entities/training_diary_entry.dart';
import 'package:coachsly/domain/entities/user.dart';
import 'package:coachsly/domain/entities/workout_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DataSource {
  // Аутентификация
  Future<AuthResponse> signUp(String email, String password);
  Future<AuthResponse> signIn(String email, String password);
  Future<void> signOut();
  Future<Map<String, dynamic>?> checkAuthStatus();

  // Клиенты
  Future<List<Map<String, dynamic>>> getClients(String trainerId);
  Future<void> addClient(Map<String, dynamic> clientData);
  Future<void> updateClient(Map<String, dynamic> clientData);

  // Расписания
  Future<List<Map<String, dynamic>>> getSchedules(String userId);
  Future<void> addSchedule(Map<String, dynamic> schedule);
  Future<void> updateSchedule(Map<String, dynamic> schedule);
  Future<void> deleteSchedule(String scheduleId);

  // Дневник тренировок
  Future<List<Map<String, dynamic>>> getTrainingDiaryEntries(String userId);
  Future<void> addTrainingDiaryEntry(Map<String, dynamic> entry);

  // Планы тренировок
  Future<List<Map<String, dynamic>>> getWorkoutPlans(String userId);
  Future<void> addWorkoutPlan(Map<String, dynamic> plan);
  Future<void> changeWorkoutPlan(Map<String, dynamic> plan);
}