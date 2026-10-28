import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';

// ─────────────────────────────────────────────────────────────
//  PendingSyncService
//
//  Очередь несохранённых из-за плохой сети запросов.
//  Используется для onboarding-настроек: реквизиты/стоимость,
//  FatSecret, механизм удержания.
//
//  При неудачном сохранении операция кладётся в SharedPreferences.
//  При следующем запуске (или вызове flushAll) — повторная попытка.
//  При успехе — запись удаляется из очереди.
// ─────────────────────────────────────────────────────────────

class PendingSyncService {
  static const _prefsKey = 'pending_sync_operations';

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(queue));
  }

  Future<void> _enqueue(Map<String, dynamic> operation) async {
    final queue = await _readQueue();
    // Если есть операция того же типа для того же пользователя — заменяем
    queue.removeWhere((op) =>
    op['type'] == operation['type'] &&
        op['userId'] == operation['userId']);
    queue.add(operation);
    await _writeQueue(queue);
  }

  // ── Постановка в очередь ──

  Future<void> queuePaymentDetails(
      String trainerId,
      Map<String, dynamic> data,
      ) async {
    await _enqueue({
      'type': 'payment_details',
      'userId': trainerId,
      'data': data,
    });
  }

  Future<void> queueFatsecret(String userId, bool value) async {
    await _enqueue({
      'type': 'fatsecret',
      'userId': userId,
      'data': {'value': value},
    });
  }

  Future<void> queueRetention(String userId, bool value) async {
    await _enqueue({
      'type': 'retention',
      'userId': userId,
      'data': {'value': value},
    });
  }

  Future<void> queueTrainerProfile(
      String userId,
      Map<String, dynamic> data,
      ) async {
    await _enqueue({
      'type': 'trainer_profile',
      'userId': userId,
      'data': data,
    });
  }

  // ── Повторная отправка ──

  /// Пытается сохранить все накопленные операции.
  /// Успешные удаляются из очереди, неудачные остаются для следующей попытки.
  Future<void> flushAll() async {
    final queue = await _readQueue();
    if (queue.isEmpty) return;

    final ds = GetIt.instance<SupabaseDataSource>();
    final remaining = <Map<String, dynamic>>[];

    for (final op in queue) {
      try {
        final type = op['type'] as String;
        final userId = op['userId'] as String;
        final data = op['data'] as Map<String, dynamic>;

        switch (type) {
          case 'payment_details':
            await ds.saveTrainerPaymentDetails(
              trainerId: userId,
              phoneNumber: data['phoneNumber'] as String? ?? '',
              preferredBank: data['preferredBank'] as String?,
              singlePrice: (data['singlePrice'] as num?)?.toDouble(),
              blockPrice: (data['blockPrice'] as num?)?.toDouble(),
              blockSessions: data['blockSessions'] as int?,
              subscriptionPrice:
              (data['subscriptionPrice'] as num?)?.toDouble(),
              subscriptionDays: data['subscriptionDays'] as int?,
            );
            break;
          case 'fatsecret':
            await ds.setFatsecretNeeded(userId, data['value'] as bool);
            break;
          case 'retention':
            await ds.setRetentionEnabled(userId, data['value'] as bool);
            break;
          case 'trainer_profile':
            await ds.updateTrainerProfile(
              trainerId: userId,
              timezone: data['timezone'] as String?,
              location: data['location'] as String?,
            );
            break;
        }
        // Успех — не добавляем в remaining
      } catch (e) {
        debugPrint('PendingSyncService: операция не выполнена, оставляем в очереди: $e');
        remaining.add(op);
      }
    }

    await _writeQueue(remaining);

    if (remaining.length < queue.length) {
      debugPrint(
          'PendingSyncService: синхронизировано ${queue.length - remaining.length} из ${queue.length}');
    }
  }
}
