// Секреты передаются через --dart-define при сборке:
//
//   flutter run \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJ...
//
// Для удобства локальной разработки создайте файл dart_defines.env:
//   SUPABASE_URL=https://xxx.supabase.co
//   SUPABASE_ANON_KEY=eyJ...
// И запускайте: flutter run --dart-define-from-file=dart_defines.env
//
// dart_defines.env добавьте в .gitignore — он НЕ должен попадать в репозиторий.
// assets/.env можно удалить.

class SupabaseConstants {
  // Compile-time константы — встраиваются в бинарник при сборке,
  // не читаются из файла во время выполнения.
  static const String supabaseUrl =
  String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
  String.fromEnvironment('SUPABASE_ANON_KEY');

  // Проверка при старте приложения
  static void assertConfigured() {
    assert(
    supabaseUrl.isNotEmpty,
    'SUPABASE_URL не задан. Запустите с --dart-define=SUPABASE_URL=...',
    );
    assert(
    supabaseAnonKey.isNotEmpty,
    'SUPABASE_ANON_KEY не задан. Запустите с --dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  static const String usersTable              = 'users';
  static const String clientsTable            = 'telegram_clients';
  static const String subscriptionsTable      = 'subscriptions';
  static const String trainingBlocksTable     = 'training_blocks';
  static const String workoutProgramsTable    = 'workout_plans';
  static const String clientWorkoutProgramsTable = 'assigned_workout_programs';
  static const String quickWorkoutProgramsTable  = 'quick_workout_plans';
  static const String schedulesTable          = 'bookings';
  static const String trainingDiaryTable      = 'training_diary';
  static const String paymentsTable           = 'payments';
  static const String assignedQuickPlansTable = 'assigned_quick_plans';

  static String get generateWorkoutPlanEndpoint =>
      '$supabaseUrl/functions/v1/deepseek-generate-workout-plan';
}
