import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:formeo/domain/entities/notification.dart';
import 'package:formeo/presentation/providers/notifications_provider.dart';
import 'package:formeo/ui/widgets/universal_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'all';

  final List<_FilterOption> _filters = const [
    _FilterOption(value: 'all', label: 'Все', icon: Icons.notifications),
    _FilterOption(
        value: 'payment_receipt',
        label: 'Оплаты',
        icon: Icons.monetization_on_rounded),
    _FilterOption(
        value: 'new_client',
        label: 'Клиенты',
        icon: Icons.emoji_people_rounded),
    _FilterOption(
        value: 'trainer_no_response',
        label: 'Нет ответа',
        icon: Icons.notifications_off_outlined),
    _FilterOption(
        value: 'retention_signal',
        label: 'Риск ухода',
        icon: Icons.warning_amber_rounded),
    _FilterOption(
        value: 'progress_report_sent',
        label: 'Отчёты',
        icon: Icons.insights_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider?>();
    final all = provider?.notifications ?? [];
    final filtered = _selectedFilter == 'all'
        ? all
        : all.where((n) => n.type.toLowerCase() == _selectedFilter).toList();
    final grouped = _groupByMonth(filtered);

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: all.isEmpty
                ? const Center(child: Text('Список уведомлений пуст'))
                : filtered.isEmpty
                ? Center(
              child: Text(
                'Нет уведомлений по выбранному фильтру',
                style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                  Theme.of(context).colorScheme.outline,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final group = grouped[index];

                if (group is _MonthHeader) {
                  return Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      group.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        Theme.of(context).colorScheme.outline,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                }

                final n = (group as _NotificationEntry).notification;
                return _buildNotificationRow(context, n, provider!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context)
                    .colorScheme
                    .surface
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter.icon,
                    size: 14,
                    color: isSelected
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationRow(
      BuildContext context,
      NotificationItem n,
      NotificationsProvider? provider,
      ) {
    final localDate = n.createdAt.toLocal();
    final dayStr = DateFormat('dd').format(localDate);
    final weekdayStr = DateFormat('EEE', 'ru_RU').format(localDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: n.isRead
                        ? Theme.of(context).colorScheme.outline
                        : Theme.of(context).colorScheme.surface,
                  ),
                ),
                Text(
                  weekdayStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: UniversalCardV2(
              item: n,
              onTap: () async {
                if (!n.isRead) {
                  await provider?.markAsRead(n.id);
                }
                if (context.mounted) {
                  context.pushNamed('notificationDetail', extra: n);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Object> _groupByMonth(List<NotificationItem> notifications) {
    final result = <Object>[];
    String? lastMonthKey;
    final monthFormatter = DateFormat('LLLL yyyy', 'ru_RU');

    for (final n in notifications) {
      final local = n.createdAt.toLocal();
      final monthKey = '${local.year}-${local.month}';
      final monthLabel = _capitalizeFirst(monthFormatter.format(local));

      if (monthKey != lastMonthKey) {
        result.add(_MonthHeader(label: monthLabel));
        lastMonthKey = monthKey;
      }

      result.add(_NotificationEntry(notification: n));
    }

    return result;
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _FilterOption {
  final String value;
  final String label;
  final IconData icon;

  const _FilterOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _MonthHeader {
  final String label;
  const _MonthHeader({required this.label});
}

class _NotificationEntry {
  final NotificationItem notification;
  const _NotificationEntry({required this.notification});
}
