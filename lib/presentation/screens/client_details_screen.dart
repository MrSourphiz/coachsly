import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/core/constants/colors.dart';

class ClientDetailsScreen extends StatelessWidget {
  final Client client;

  const ClientDetailsScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${client.first_name} ${client.last_name}'),
        backgroundColor: AppColors.colorLightBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerSection(),
            const SizedBox(height: 20),
            _infoSection(),
            const SizedBox(height: 20),
            _programSection(),
            const SizedBox(height: 20),
            _actionsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _headerSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.colorLightBlue,
          child: Text(
            client.first_name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 32, color: AppColors.colorWhite),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${client.first_name} ${client.last_name}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(client.status),
          ],
        )
      ],
    );
  }

  Widget _infoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Информация', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _infoTile('Телефон', client.phoneNumber ?? '—'),
        _infoTile('Статус', client.status),
        if (client.notes != null && client.notes!.isNotEmpty)
          _infoTile('Заметки', client.notes!),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _programSection() {
    final hasProgram = client.hasActiveProgram;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Тренировочная программа', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (!hasProgram) ...[
          const Text('Нет активной тренировочной программы'),
        ] else ...[
          _infoTile('ID программы', client.assignedProgramId ?? '—'),
          _infoTile('Дни тренировок', client.trainingDays?.join(', ') ?? '—'),
          _infoTile('Длительность (недели)', client.durationWeeks?.toString() ?? '—'),
        ],
      ],
    );
  }

  Widget _actionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Действия', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _openTelegram,
          child: const Text('Написать клиенту'),
        ),
      ],
    );
  }

  Future<void> _openTelegram() async {
    final id = client.telegramUserId; // имя поля подставьте своё
    if (id == null || id == 0) return;

    final uri = Uri.parse('tg://user?id=$id');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // fallback через https
      final fallback = Uri.parse('https://t.me/$id');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }
}
