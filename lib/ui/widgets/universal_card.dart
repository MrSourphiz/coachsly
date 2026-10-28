import 'package:flutter/material.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/domain/entities/workout_plan_model.dart';
import 'package:formeo/domain/entities/quick_workout_plan.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/core/constants/colors.dart';

class UniversalCardV2 extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onTap;

  /// Уровень активного сигнала удержания для этого клиента —
  /// 'red' | 'yellow' | null (сигналов нет / механизм выключен).
  /// Используется только когда [item] — Client; передаётся из
  /// clients_screen.dart, где сигналы подгружаются через RetentionBloc.
  final String? retentionSignalLevel;

  const UniversalCardV2({
    super.key,
    required this.item,
    this.onTap,
    this.retentionSignalLevel,
  });

  Color? get _signalColor {
    switch (retentionSignalLevel) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'yellow':
        return const Color(0xFFF59E0B);
      default:
        return null;
    }
  }

  /// duration хранится в днях (см. totalDays в create_workout_plan_screen.dart)
  /// — добавляем склонение день/дня/дней вместо голого числа.
  String _durationLabel(int? duration) {
    if (duration == null) return '—';
    final mod10 = duration % 10;
    final mod100 = duration % 100;
    if (mod10 == 1 && mod100 != 11) return '$duration день';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
      return '$duration дня';
    }
    return '$duration дней';
  }

  String textByNotifyType(String type, Map<String, dynamic> payload) {
    switch (type.toLowerCase()) {
      case 'payment_receipt':
        final clientName = payload['client_name'] ?? '';
        final purchaseType = payload['purchase_type'] ?? '';
        if (purchaseType == 'single') {
          return 'Клиент $clientName - Чек оплаты за тренировку'.trim();
        } else if (purchaseType == 'block') {
          return 'Клиент $clientName - Чек оплаты за блок тренировок'.trim();
        } else if (purchaseType == 'subscription') {
          return 'Клиент $clientName - Чек оплаты за абонемент'.trim();
        } else {
          return 'Неизвестное уведомление';
        }
      case 'trainer_no_response':
        final clientName = payload['client_name'] ?? '';
        return 'Клиент $clientName - проигнорировал уведомление о тренировке'.trim();
      case 'new_client':
        final firstName = payload['first_name'] ?? '';
        final lastName = payload['last_name'] ?? '';
        final fullName = '$firstName $lastName'.trim();
        return fullName.isNotEmpty
            ? 'Добавлен новый клиент $fullName'
            : 'Добавлен новый клиент';
      case 'retention_signal':
        final title = (payload['title'] as String?)?.trim();
        if (title != null && title.isNotEmpty) return title;
        final signalLevel = payload['signal_level'] as String?;
        return signalLevel == 'red'
            ? '🔴 Клиент под риском ухода'
            : '🟡 Клиент начинает пропускать';
      case 'progress_report_sent':
        final title = (payload['title'] as String?)?.trim();
        return (title != null && title.isNotEmpty)
            ? title
            : '📊 Прогресс-срез отправлен';
      default:
        return 'Неизвестное уведомление';
    }
  }

  String? subtitleByNotifyType(String type, Map<String, dynamic> payload) {
    switch (type.toLowerCase()) {
      case 'retention_signal':
      case 'progress_report_sent':
        final body = (payload['body'] as String?)?.trim();
        return (body != null && body.isNotEmpty) ? body : null;
      default:
        return null;
    }
  }

  String _sessionTypeLabel(String type) {
    switch (type) {
      case 'single':
        return 'Текущий тип занятий: Разовые занятия';
      case 'subscription':
        return 'Текущий тип занятий: Абонемент';
      case 'block':
        return 'Текущий тип занятий: Блок занятий';
      default:
        return type;
    }
  }

  IconData iconByNotifyType(String type) {
    switch (type.toLowerCase()) {
      case 'payment_receipt':
        return Icons.monetization_on_rounded;
      case 'new_client':
        return Icons.emoji_people_rounded;
      case 'retention_signal':
        return Icons.warning_amber_rounded;
      case 'progress_report_sent':
        return Icons.insights_rounded;
      default:
        return Icons.notifications;
    }
  }

  Color? iconColorByNotifyType(String type, Map<String, dynamic> payload) {
    switch (type.toLowerCase()) {
      case 'retention_signal':
        final signalLevel = payload['signal_level'] as String?;
        return signalLevel == 'red' ? AppColors.colorRed : Colors.amber;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    late final String title;
    String? subtitle;
    final IconData leadingIcon;
    Color? leadingIconColor;

    if (item is Client) {
      title = "${item.firstName}  ${item.lastName}";
      subtitle = _sessionTypeLabel(item.defaultSessionType);
      leadingIcon = Icons.emoji_people;
    } else if (item is NotificationItem) {
      title = textByNotifyType(item.type, item.payload);
      subtitle = subtitleByNotifyType(item.type, item.payload);
      leadingIcon = iconByNotifyType(item.type);
      leadingIconColor = iconColorByNotifyType(item.type, item.payload);
    } else if (item is WorkoutPlan) {
      title = item.name ?? 'Без названия';
      subtitle = "${item.typeLabel} — ${_durationLabel(item.duration)}";
      leadingIcon = Icons.fitness_center;
    } else if (item is QuickWorkoutPlan) {
      title = item.name;
      subtitle = "${item.typeLabel} — ${_durationLabel(item.duration)}";
      leadingIcon = Icons.fitness_center;
    } else {
      title = "Неизвестный элемент";
      subtitle = item.toString();
      leadingIcon = Icons.help_outline;
    }

    final signalColor = _signalColor;

    return Card(
      color: AppColors.colorLightBlue,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: signalColor != null
            ? BorderSide(color: signalColor.withValues(alpha: 0.55), width: 1.2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          // Цветная полоса слева — проблемный клиент виден даже при беглом
          // просмотре списка, не только по цвету рамки карточки.
          decoration: signalColor != null
              ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: signalColor, width: 4)),
          )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              // ✅ crossAxisAlignment.center — карточка выравнивает аватар и текст по центру
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEADING
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.colorLightBlue,
                  child: Icon(
                    leadingIcon,
                    color: leadingIconColor ?? AppColors.colorGrey,
                  ),
                ),
                const SizedBox(width: 12),

                // CONTENT
                Expanded(
                  child: Column(
                    // ✅ min — колонка занимает ровно столько места, сколько нужно тексту,
                    // не пытается растянуться на всю высоту родителя
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (signalColor != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: signalColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17,
                                  color: AppColors.colorWhite,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.colorWhite,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // TRAILING
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item is NotificationItem && item.isRead == false)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.colorDarkRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: AppColors.colorGrey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}