import 'package:flutter/material.dart';
import 'package:coachsly/domain/entities/notification.dart';
import 'package:coachsly/domain/entities/workout_plan_model.dart';
import 'package:coachsly/domain/entities/quick_workout_plan.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/core/constants/colors.dart';

class UniversalCardV2 extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onTap;

  const UniversalCardV2({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Определяем тип и подготавливаем отображение
    late final String title;
    String? subtitle;
    IconData? leadingIcon;
    String? leadingText;

    if (item is Client) {
      title = "${item.first_name}  ${item.last_name}";
      subtitle = item.status;
      leadingText = item.first_name.substring(0, 1).toUpperCase();
      leadingIcon = Icons.emoji_people;
    } else if (item is NotificationItem) {
      title = item.type;
    //  subtitle = item.payload;
      leadingIcon = Icons.notifications;
    } else if (item is WorkoutPlan) {
      title = item.name;
      subtitle = "${item.type} — ${item.duration}";
      leadingIcon = Icons.fitness_center;
    } else if (item is QuickWorkoutPlan) {
      title = item.name;
      subtitle = "${item.type} — ${item.duration}";
      leadingIcon = Icons.fitness_center;
    } else {
      // fallback вариант
      title = "Неизвестный элемент";
      subtitle = item.toString();
      leadingIcon = Icons.help_outline;
    }

    return Card(
      color: AppColors.colorLightBlue,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // LEADING
              if (leadingIcon != null || leadingText != null)
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.colorLightBlue,
                  child: leadingIcon != null
                      ? Icon(leadingIcon, color: AppColors.colorGrey)
                      : Text(
                    leadingText!,
                    style: const TextStyle(color: AppColors.colorWhite, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 12),

              // CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, color: AppColors.colorWhite, fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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
    );
  }
}