import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/domain/entities/retention_onboarding.dart';
import 'package:formeo/domain/entities/retention_signal.dart';
import 'package:formeo/presentation/blocs/retention_bloc.dart';

// =============================================================================
// RetentionClientSection
// Главный виджет — встраивается в client_details_screen.dart
//
// Использование:
//   RetentionClientSection(
//     clientId: _client.id,
//     trainerId: _client.trainerId,
//     telegramUserId: _client.telegramUserId,
//     clientCreatedAt: _client.createdAt,
//   )
// =============================================================================

// Грейс-период для новых клиентов — держи синхронно с
// public.retention_grace_days() в БД и GRACE_PERIOD_DAYS в
// retention-checkin-sender/index.ts. Сейчас везде 14 дней.
const int kRetentionGraceDays = 14;

/// true, если клиент всё ещё в грейс-периоде (данных мало,
/// чек-ины/сигналы ещё не создаются).
bool _isInGracePeriod(DateTime clientCreatedAt) {
  final daysSinceCreated = DateTime.now().difference(clientCreatedAt).inDays;
  return (kRetentionGraceDays - daysSinceCreated) > 0;
}

int _graceDaysLeft(DateTime clientCreatedAt) {
  final daysSinceCreated = DateTime.now().difference(clientCreatedAt).inDays;
  return kRetentionGraceDays - daysSinceCreated;
}

class RetentionClientSection extends StatelessWidget {
  final String clientId;
  final String trainerId;
  final int telegramUserId;
  final DateTime clientCreatedAt;
  final bool isDemo;

  const RetentionClientSection({
    super.key,
    required this.clientId,
    required this.trainerId,
    required this.telegramUserId,
    required this.clientCreatedAt,
    this.isDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<RetentionBloc>()
        ..add(LoadRetentionEnabledEvent(clientId))
        ..add(LoadOnboardingEvent(clientId: clientId, trainerId: trainerId))
        ..add(LoadActiveSignalsEvent(trainerId)),
      child: _RetentionClientSectionBody(
        clientId: clientId,
        trainerId: trainerId,
        telegramUserId: telegramUserId,
        clientCreatedAt: clientCreatedAt,
        isDemo: isDemo,
      ),
    );
  }
}

class _RetentionClientSectionBody extends StatelessWidget {
  final String clientId;
  final String trainerId;
  final int telegramUserId;
  final DateTime clientCreatedAt;
  final bool isDemo;

  const _RetentionClientSectionBody({
    required this.clientId,
    required this.trainerId,
    required this.telegramUserId,
    required this.clientCreatedAt,
    this.isDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetentionBloc, RetentionState>(
      buildWhen: (prev, curr) => curr is RetentionEnabledLoaded,
      builder: (context, state) {
        final enabled = state is RetentionEnabledLoaded ? state.enabled : true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Тоггл включения/отключения механизма
            _RetentionToggle(
              clientId: clientId,
              trainerId: trainerId,
              telegramUserId: telegramUserId,
              enabled: enabled,
            ),

            // Контент показывается только если механизм включён
            if (enabled) ...[
              const SizedBox(height: 12),
              // Пока клиент в грейс-периоде — данных мало, сигналов не будет.
              // У демо-клиентов история уже "прожита" заранее — грейс-период
              // для них не имеет смысла, сразу показываем сигналы.
              if (!isDemo && _isInGracePeriod(clientCreatedAt))
                _NewClientGraceBadge(daysLeft: _graceDaysLeft(clientCreatedAt))
              else
                _RetentionSignalsWidget(clientId: clientId),
              const SizedBox(height: 12),
              _RetentionProfileCard(clientId: clientId, trainerId: trainerId),
            ],
          ],
        );
      },
    );
  }
}

// =============================================================================
// RetentionAlertsBar — тоггл + активные сигналы, для верхней "always visible"
// зоны экрана клиента (над табами, видна независимо от выбранного таба)
// =============================================================================

class RetentionAlertsBar extends StatelessWidget {
  final String clientId;
  final String trainerId;
  final int telegramUserId;
  final DateTime clientCreatedAt;
  final bool isDemo;

  const RetentionAlertsBar({
    super.key,
    required this.clientId,
    required this.trainerId,
    required this.telegramUserId,
    required this.clientCreatedAt,
    this.isDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<RetentionBloc>()
        ..add(LoadRetentionEnabledEvent(clientId))
        ..add(LoadActiveSignalsEvent(trainerId)),
      child: BlocBuilder<RetentionBloc, RetentionState>(
        buildWhen: (prev, curr) => curr is RetentionEnabledLoaded,
        builder: (context, state) {
          final enabled = state is RetentionEnabledLoaded ? state.enabled : true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RetentionToggle(
                clientId: clientId,
                trainerId: trainerId,
                telegramUserId: telegramUserId,
                enabled: enabled,
              ),
              if (enabled) ...[
                const SizedBox(height: 10),
                // Пока клиент в грейс-периоде — объясняем тренеру тишину,
                // а не показываем (заведомо пустой) список сигналов.
                // У демо-клиентов грейс-период не применим — у них уже
                // есть заранее засеянная история и сигналы.
                if (!isDemo && _isInGracePeriod(clientCreatedAt))
                  _NewClientGraceBadge(daysLeft: _graceDaysLeft(clientCreatedAt))
                else
                  _RetentionSignalsWidget(clientId: clientId),
              ],
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// RetentionProfileSection — профиль клиента из онбординга, для таба "Обзор"
// =============================================================================

class RetentionProfileSection extends StatelessWidget {
  final String clientId;
  final String trainerId;

  const RetentionProfileSection({
    super.key,
    required this.clientId,
    required this.trainerId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<RetentionBloc>()
        ..add(LoadRetentionEnabledEvent(clientId))
        ..add(LoadOnboardingEvent(clientId: clientId, trainerId: trainerId)),
      child: BlocBuilder<RetentionBloc, RetentionState>(
        buildWhen: (prev, curr) => curr is RetentionEnabledLoaded,
        builder: (context, state) {
          final enabled = state is RetentionEnabledLoaded ? state.enabled : true;
          if (!enabled) return const SizedBox.shrink();
          return _RetentionProfileCard(clientId: clientId, trainerId: trainerId);
        },
      ),
    );
  }
}

// =============================================================================
// _NewClientGraceBadge — объясняет тренеру, почему по новому клиенту
// пока нет чек-инов/сигналов
// =============================================================================

class _NewClientGraceBadge extends StatelessWidget {
  final int daysLeft;
  const _NewClientGraceBadge({required this.daysLeft});

  String _daysLabel(int days) {
    final mod10 = days % 10;
    final mod100 = days % 100;
    if (mod10 == 1 && mod100 != 11) return '$days день';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
      return '$days дня';
    }
    return '$days дней';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colorWhite.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: AppColors.colorWhite.withOpacity(0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новый клиент — собираем данные',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysLeft > 1
                      ? 'Чек-ины и сигналы начнут приходить через ${_daysLabel(daysLeft)}'
                      : 'Чек-ины и сигналы начнут приходить уже завтра',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.colorWhite.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _RetentionToggle — тоггл включения механизма удержания
// =============================================================================

class _RetentionToggle extends StatelessWidget {
  final String clientId;
  final String trainerId;
  final int telegramUserId;
  final bool enabled;

  const _RetentionToggle({
    required this.clientId,
    required this.trainerId,
    required this.telegramUserId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? AppColors.colorWhite.withOpacity(0.15)
              : AppColors.colorWhite.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.shield_rounded : Icons.shield_outlined,
            size: 18,
            color: enabled
                ? AppColors.colorWhite
                : AppColors.colorWhite.withOpacity(0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Механизм удержания',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.colorWhite
                        : AppColors.colorWhite.withOpacity(0.45),
                  ),
                ),
                Text(
                  enabled
                      ? 'Опрос · чек-ины · сигналы · срезы'
                      : 'Отключён — только базовые уведомления',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.colorWhite
                        .withOpacity(enabled ? 0.5 : 0.3),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (value) {
              context.read<RetentionBloc>().add(
                SetRetentionEnabledEvent(
                  clientId: clientId,
                  trainerId: trainerId,
                  telegramUserId: telegramUserId,
                  enabled: value,
                ),
              );
            },
            activeColor: AppColors.colorDarkRed,
            activeTrackColor: AppColors.colorDarkRed.withOpacity(0.35),
            inactiveThumbColor: AppColors.colorWhite.withOpacity(0.35),
            inactiveTrackColor: AppColors.colorWhite.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _RetentionSignalsWidget — активные сигналы 🔴🟡 по этому клиенту
// =============================================================================

class _RetentionSignalsWidget extends StatelessWidget {
  final String clientId;
  const _RetentionSignalsWidget({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetentionBloc, RetentionState>(
      buildWhen: (prev, curr) =>
      curr is SignalsLoaded || curr is RetentionLoading,
      builder: (context, state) {
        if (state is RetentionLoading) return const SizedBox.shrink();
        if (state is! SignalsLoaded) return const SizedBox.shrink();

        final signals = state.signals
            .where((s) => s.clientId == clientId && !s.isResolved)
            .toList();

        if (signals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: signals.map((s) => _SignalCard(signal: s)).toList(),
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  final RetentionSignal signal;
  const _SignalCard({required this.signal});

  Color get _bgColor {
    switch (signal.signalLevel) {
      case 'red':
        return const Color(0xFF7F1D1D).withOpacity(0.85);
      case 'yellow':
        return const Color(0xFF78350F).withOpacity(0.85);
      default:
        return const Color(0xFF14532D).withOpacity(0.85);
    }
  }

  Color get _borderColor {
    switch (signal.signalLevel) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'yellow':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(signal.levelEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.signalLevel == 'red'
                      ? 'Клиент под риском ухода'
                      : 'Клиент начинает пропускать',
                  style: const TextStyle(
                    color: AppColors.colorWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signal.reasonLabel,
                  style: TextStyle(
                    color: AppColors.colorWhite.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.colorWhite.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: AppColors.colorWhite.withOpacity(0.75),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          signal.advice,
                          style: TextStyle(
                            color: AppColors.colorWhite.withOpacity(0.85),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<RetentionBloc>().add(
                ResolveSignalEvent(
                  signalId: signal.id,
                  trainerId: signal.trainerId,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.colorWhite,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Решено', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _RetentionProfileCard — профиль клиента из онбординг-опроса
// =============================================================================

class _RetentionProfileCard extends StatelessWidget {
  final String clientId;
  final String trainerId;

  const _RetentionProfileCard({
    required this.clientId,
    required this.trainerId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetentionBloc, RetentionState>(
      buildWhen: (prev, curr) =>
      curr is OnboardingAlreadyDone ||
          curr is OnboardingNeeded ||
          curr is RetentionLoading,
      builder: (context, state) {
        if (state is RetentionLoading) {
          return const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (state is OnboardingNeeded) {
          return _buildNotCompleted();
        }

        if (state is OnboardingAlreadyDone) {
          return _buildProfile(state.onboarding);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildNotCompleted() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colorWhite.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined,
              color: AppColors.colorWhite.withOpacity(0.5), size: 20),
          const SizedBox(width: 10),
          Text(
            'Клиент ещё не прошёл стартовый опрос',
            style: TextStyle(
              color: AppColors.colorWhite.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(RetentionOnboarding onboarding) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colorWhite.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.colorWhite, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Профиль клиента',
                style: TextStyle(
                  color: AppColors.colorWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              _ClientTypeBadge(onboarding: onboarding),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.flag_outlined,
            label: 'Цель',
            value: onboarding.goalTypeLabel,
          ),
          if (onboarding.goalDescription != null &&
              onboarding.goalDescription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ProfileRow(
              icon: Icons.track_changes_outlined,
              label: 'Результат',
              value: onboarding.goalDescription!,
            ),
          ],
          const SizedBox(height: 6),
          _ProfileRow(
            icon: Icons.favorite_outline,
            label: 'Самочувствие на старте',
            value: '${onboarding.baseWellbeing}/5',
            valueColor: _wellbeingColor(onboarding.baseWellbeing),
          ),
          if (onboarding.experienceType == 'yo_yo' &&
              onboarding.quitReason != null) ...[
            const SizedBox(height: 6),
            _ProfileRow(
              icon: Icons.warning_amber_outlined,
              label: 'Причина ухода в прошлый раз',
              value: _quitReasonLabel(onboarding.quitReason!),
              valueColor: const Color(0xFFF59E0B),
            ),
          ],
          const SizedBox(height: 6),
          _ProfileRow(
            icon: Icons.support_outlined,
            label: 'Нужная опека',
            value: _supportLabel(onboarding.gymConfidence),
          ),
          const SizedBox(height: 6),
          _ProfileRow(
            icon: Icons.handshake_outlined,
            label: 'Стиль работы',
            value: _coachingStyleLabel(onboarding.coachingStyle),
          ),
        ],
      ),
    );
  }

  Color _wellbeingColor(int score) {
    if (score <= 2) return const Color(0xFFEF4444);
    if (score == 3) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  String _quitReasonLabel(String reason) {
    const labels = {
      'no_time': 'Не хватало времени',
      'not_enough_time': 'Не хватало времени', // алиас на случай устаревших/ошибочных данных
      'no_results': 'Не видел результата',
      'lost_motivation': 'Потерял мотивацию',
      'injury': 'Травма или здоровье',
      'finances': 'Финансы',
      'other': 'Другое',
    };
    return labels[reason] ?? reason;
  }

  String _supportLabel(String confidence) {
    const labels = {
      'confident': 'Низкая — самостоятельный',
      'somewhat': 'Средняя — периодические подсказки',
      'needs_support': 'Высокая — нужна структура',
    };
    return labels[confidence] ?? confidence;
  }

  String _coachingStyleLabel(String style) {
    const labels = {
      'structured': 'Чёткий план и контроль',
      'collaborative': 'Совместная работа',
      'free': 'Минимум указаний',
    };
    return labels[style] ?? style;
  }
}

// =============================================================================
// Вспомогательные виджеты
// =============================================================================

class _ClientTypeBadge extends StatelessWidget {
  final RetentionOnboarding onboarding;
  const _ClientTypeBadge({required this.onboarding});

  Color get _color {
    switch (onboarding.riskLevel) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Text(
        onboarding.clientTypeLabel,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.colorWhite.withOpacity(0.45)),
        const SizedBox(width: 6),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.colorWhite.withOpacity(0.55),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? AppColors.colorWhite,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}