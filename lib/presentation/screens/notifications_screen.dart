import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coachsly/domain/entities/notification.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/domain/repositories/notifications_repository.dart';
import 'package:coachsly/ui/widgets/universal_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trainerId = context.read<UserProvider>().user?.id;
    print('trainerId from provider: $trainerId');
    if (trainerId == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не авторизован')),
      );
    }

    final notificationRepository = context.read<NotificationsRepository>();
    final notificationStream = notificationRepository.subscribeNotifications(trainerId);

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: StreamBuilder<List<NotificationItem>>(
        stream: notificationStream,
        builder: (context, snapshot) {
          print('snapshot: $snapshot.data');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Список уведомлений пуст'),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return UniversalCardV2(
                item: n,
                onTap: () => Navigator.pushNamed(context, '/notificationDetail'),
              );
//              return ListTile(
//                title: Text(n.type),
//                subtitle: Text(n.payload?.toString() ?? ''),
//                trailing: n.isRead ? null : const Icon(Icons.circle, color: Colors.red, size: 10),
//              );
            },
          );
        },
      ),
    );
  }
}
