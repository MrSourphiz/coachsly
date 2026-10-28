import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/core/constants/colors.dart';

// ─────────────────────────────────────────────────────────────
//  OnboardingProgressService
//
//  Единый источник прогресса для всего флоу онбординга.
//  Регистрируется как lazySingleton в GetIt.
//
//  11 шагов:
//   0–4   → OnboardingInfoScreen (5 информационных слайдов)
//   5–10  → OnboardingScreen     (6 шагов настройки: профиль,
//           приглашение, реквизиты, FatSecret, удержание,
//           быстрая загрузка программ)
//   пейволл — без прогресса
// ─────────────────────────────────────────────────────────────

class OnboardingProgressService extends ChangeNotifier {
  static const int totalSteps = 11;

  int _currentStep = 0;

  int get currentStep => _currentStep;

  void setStep(int step) {
    if (_currentStep == step) return;
    _currentStep = step.clamp(0, totalSteps - 1);
    notifyListeners();
  }

  void reset() {
    _currentStep = 0;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────
//  OnboardingProgressBar
//
//  Виджет прогресс-бара. Слушает OnboardingProgressService
//  и отрисовывает 11 точек/чёрточек.
// ─────────────────────────────────────────────────────────────

class OnboardingProgressBar extends StatefulWidget {
  const OnboardingProgressBar({super.key});

  @override
  State<OnboardingProgressBar> createState() => _OnboardingProgressBarState();
}

class _OnboardingProgressBarState extends State<OnboardingProgressBar> {
  late final OnboardingProgressService _service;

  @override
  void initState() {
    super.initState();
    _service = GetIt.instance<OnboardingProgressService>();
    _service.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _service.currentStep;
    return Row(
      children: List.generate(OnboardingProgressService.totalSteps, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 5),
          width: isActive ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive || isDone
                ? AppColors.colorDarkRed
                : AppColors.colorWhite.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
