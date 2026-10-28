import 'package:flutter/material.dart';
import 'package:formeo/core/constants/billing_config.dart';
import 'package:formeo/core/constants/colors.dart';

// ─────────────────────────────────────────────────────────────
//  Экраны доступа для iOS (вместо пейволла).
//
//  ⚠️ Здесь НЕ должно быть: цен, названий тарифов, слов «оплатить»,
//  «купить», «подписка на сайте», ссылок на myformeo.ru/account.
//  Любой призыв к оплате вне App Store = отказ по правилу 3.1.1.
// ─────────────────────────────────────────────────────────────

/// Показывается после онбординга вместо выбора тарифа.
class IosAccessIntro extends StatelessWidget {
  final VoidCallback? onStart;

  const IosAccessIntro({super.key, required this.onStart});

  static const _features = [
    'Уведомления клиентам о тренировках',
    'Учёт блоков и абонементов',
    'Контроль оплат от клиентов',
    'Механизм удержания клиентов',
    'Интеграция с FatSecret',
    'Быстрая загрузка программ',
  ];

  @override
  Widget build(BuildContext context) {
    return _Shell(
      emoji: '🚀',
      title: 'Всё готово!',
      subtitle: 'Следующие 14 дней вам доступны все функции Formeo.',
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.colorWhite.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.colorWhite.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: _features
              .map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.check, size: 16, color: Color(0xFF34D399)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.colorWhite.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ))
              .toList(),
        ),
      ),
      actions: [
        _PrimaryButton(label: 'Начать работу', onPressed: onStart),
      ],
    );
  }
}

/// Показывается, когда доступ закончился (вместо закрытого пейволла).
class IosAccessInactive extends StatelessWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onLogout;
  final bool refreshing;

  const IosAccessInactive({
    super.key,
    required this.onRefresh,
    required this.onLogout,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Shell(
      emoji: '🔒',
      title: 'Доступ к аккаунту\nнеактивен',
      subtitle: 'Ваши клиенты, расписание и история сохранены. '
          'Как только доступ будет восстановлен, приложение откроется автоматически.',
      body: Text(
        'Вопросы: ${BillingConfig.supportEmail}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.colorWhite.withValues(alpha: 0.5),
        ),
      ),
      actions: [
        _PrimaryButton(
          label: 'Обновить статус',
          loading: refreshing,
          onPressed: refreshing ? null : onRefresh,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onLogout,
          child: Text(
            'Выйти из аккаунта',
            style: TextStyle(color: AppColors.colorWhite.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}

// ── Общая разметка ──

class _Shell extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;

  const _Shell({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.colorWhite,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.colorWhite.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              body,
              const SizedBox(height: 32),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.colorDarkRed,
          foregroundColor: AppColors.colorWhite,
          disabledBackgroundColor: AppColors.colorDarkRed.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.colorWhite,
          ),
        )
            : Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}