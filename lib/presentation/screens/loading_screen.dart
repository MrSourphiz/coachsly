import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/core/constants/colors.dart';
// ✅ Импортируем функцию записи кэша из router
import 'package:formeo/router.dart' show setOnboardingCompleted;
import 'package:formeo/core/service/pending_sync_service.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingAndNavigate();
    });
  }

  Future<void> _checkOnboardingAndNavigate() async {
    try {
      final user = GetIt.instance<UserProvider>().user;
      if (user == null) {
        if (mounted) context.go('/main');
        return;
      }

      // Пробуем досохранить то, что не сохранилось из-за сети в прошлый раз
      GetIt.instance<PendingSyncService>().flushAll();

      // ✅ Проверяем онбординг (единственный HTTP запрос за сессию)
      final completed = await GetIt.instance<SupabaseDataSource>()
          .isOnboardingCompleted(user.id);

      // Сохраняем в кэш — router больше не будет делать этот запрос
      setOnboardingCompleted(completed);

      if (!mounted) return;

      if (completed) {
        debugPrint('🔵 LoadingScreen: onboarding done → /main');
        context.go('/main');
      } else {
        debugPrint('🔵 LoadingScreen: first launch → /onboarding-info');
        context.go('/onboarding-info');
      }
    } catch (e) {
      // isOnboardingCompleted упал — нет записи в users или нет сети.
      // Если пользователь дошёл до LoadingScreen — у него есть валидная сессия.
      // Считаем онбординг пройденным и пускаем в приложение.
      // Онбординг показывать нельзя — там тоже будут падать запросы к users.
      debugPrint('🔴 LoadingScreen: error проверки онбординга: $e → идём в /main');
      setOnboardingCompleted(true);
      if (mounted) context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
