import 'package:flutter/material.dart';
import 'package:formeo/core/constants/colors.dart';

/// Плашка «Pro · Пример на демо-клиенте» для вкладок с функциями тарифа Pro
/// (Замеры, Тренировки), которые на демо-клиентах видны и без Pro —
/// чтобы тренер на триале понимал, что видит пример, а не свою функцию.
class DemoProBanner extends StatelessWidget {
  final String text;

  const DemoProBanner({
    super.key,
    this.text = 'Пример на демо-клиенте. У ваших клиентов эта функция доступна на тарифе Pro',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProBadge(),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.colorGrey),
          ),
        ),
      ],
    );
  }
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Pro',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
      ),
    );
  }
}