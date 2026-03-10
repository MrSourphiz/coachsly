import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  static const String usersTable = 'users';
  static const String clientsTable = 'telegram_clients';
  static const String workoutProgramsTable = 'workout_plans';
  static const String clientWorkoutProgramsTable = 'assigned_workout_programs';
  static const String quickWorkoutProgramsTable = 'quick_workout_plans';
  static const String schedulesTable = 'bookings';
  static const String trainingDiaryTable = 'training_diary';

  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;

  static String get generateWorkoutPlanEndpoint =>
      '$supabaseUrl/functions/v1/deepseek-generate-workout-plan';
}