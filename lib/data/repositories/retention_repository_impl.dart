import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:formeo/domain/entities/retention_onboarding.dart';
import 'package:formeo/domain/entities/retention_checkin.dart';
import 'package:formeo/domain/entities/retention_signal.dart';
import 'package:formeo/domain/repositories/retention_repository.dart';

class RetentionRepositoryImpl implements RetentionRepository {
  final SupabaseClient _client;

  RetentionRepositoryImpl(this._client);

  @override
  Future<void> setRetentionEnabled({
    required String clientId,
    required bool enabled,
  }) async {
    try {
      await _client
          .from('telegram_clients')
          .update({'retention_enabled': enabled})
          .eq('id', clientId);
    } catch (e) {
      throw Exception('Ошибка обновления retention_enabled: $e');
    }
  }

  @override
  Future<bool> getRetentionEnabled(String clientId) async {
    try {
      final data = await _client
          .from('telegram_clients')
          .select('retention_enabled')
          .eq('id', clientId)
          .maybeSingle();
      return data?['retention_enabled'] as bool? ?? true;
    } catch (e) {
      throw Exception('Ошибка получения retention_enabled: $e');
    }
  }

  @override
  Future<void> triggerOnboardingStart({
    required String clientId,
    required String trainerId,
    required int telegramUserId,
  }) async {
    try {
      final response = await _client.functions.invoke('retention-bot', body: {
        'type': 'start_onboarding',
        'payload': {
          'chat_id': telegramUserId,
          'telegram_user_id': telegramUserId.toString(),
          'client_id': clientId,
          'trainer_id': trainerId,
        },
      });

      if (response.status != 200) {
        throw Exception('Сервер вернул ${response.status}: ${response.data}');
      }
    } catch (e) {
      throw Exception('Ошибка запуска онбординга: $e');
    }
  }

  // ── Онбординг ──────────────────────────────────────────────────────────────

  @override
  Future<void> saveOnboarding(RetentionOnboarding onboarding) async {
    try {
      await _client
          .from('retention_onboarding')
          .upsert(onboarding.toJson(), onConflict: 'client_id,trainer_id');
    } catch (e) {
      throw Exception('Ошибка сохранения онбординга: $e');
    }
  }

  @override
  Future<RetentionOnboarding?> getOnboarding({
    required String clientId,
    required String trainerId,
  }) async {
    try {
      final data = await _client
          .from('retention_onboarding')
          .select()
          .eq('client_id', clientId)
          .eq('trainer_id', trainerId)
          .maybeSingle();
      if (data == null) return null;
      return RetentionOnboarding.fromJson(data);
    } catch (e) {
      throw Exception('Ошибка получения онбординга: $e');
    }
  }

  @override
  Future<bool> isOnboardingCompleted({
    required String clientId,
    required String trainerId,
  }) async {
    final result = await getOnboarding(
      clientId: clientId,
      trainerId: trainerId,
    );
    return result != null;
  }

  // ── Чек-ины ────────────────────────────────────────────────────────────────

  @override
  Future<void> saveCheckin(RetentionCheckin checkin) async {
    try {
      await _client.from('retention_checkins').insert(checkin.toJson());
    } catch (e) {
      throw Exception('Ошибка сохранения чек-ина: $e');
    }
  }

  @override
  Future<List<RetentionCheckin>> getCheckins({
    required String clientId,
    int limit = 10,
  }) async {
    try {
      final data = await _client
          .from('retention_checkins')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => RetentionCheckin.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Ошибка получения чек-инов: $e');
    }
  }

  @override
  Future<RetentionCheckin?> getLastCheckin(String clientId) async {
    try {
      final data = await _client
          .from('retention_checkins')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return RetentionCheckin.fromJson(data);
    } catch (e) {
      throw Exception('Ошибка получения последнего чек-ина: $e');
    }
  }

  @override
  Future<bool> isCheckinDue(String clientId) async {
    final last = await getLastCheckin(clientId);
    if (last == null) return true; // ни одного чек-ина — нужен
    final daysSince = DateTime.now().difference(last.createdAt).inDays;
    return daysSince >= 14;
  }

  // ── Сигналы ────────────────────────────────────────────────────────────────

  @override
  Future<void> createSignal({
    required String clientId,
    required String trainerId,
    required String signalLevel,
    required String reason,
  }) async {
    try {
      // Не дублируем активный сигнал того же типа
      final existing = await _client
          .from('retention_signals')
          .select('id')
          .eq('client_id', clientId)
          .eq('reason', reason)
          .isFilter('resolved_at', null)
          .maybeSingle();
      if (existing != null) return;

      await _client.from('retention_signals').insert({
        'client_id': clientId,
        'trainer_id': trainerId,
        'signal_level': signalLevel,
        'reason': reason,
      });
    } catch (e) {
      throw Exception('Ошибка создания сигнала: $e');
    }
  }

  @override
  Future<List<RetentionSignal>> getActiveSignals(String trainerId) async {
    try {
      final data = await _client
          .from('retention_signals')
          .select('*, telegram_clients!client_id(first_name, last_name)')
          .eq('trainer_id', trainerId)
          .isFilter('resolved_at', null)
          .order('created_at', ascending: false);

      return (data as List).map((e) {
        final clientData = e['telegram_clients'] as Map<String, dynamic>?;
        return RetentionSignal.fromJson({
          ...e,
          'client_name': '${clientData?['first_name'] ?? ''} ${clientData?['last_name'] ?? ''}'.trim(),
        });
      }).toList();
    } catch (e) {
      throw Exception('Ошибка получения сигналов: $e');
    }
  }

  @override
  Future<void> resolveSignal(String signalId) async {
    try {
      await _client
          .from('retention_signals')
          .update({'resolved_at': DateTime.now().toIso8601String()})
          .eq('id', signalId);
    } catch (e) {
      throw Exception('Ошибка закрытия сигнала: $e');
    }
  }

  // ── Прогресс-срез ──────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getClientProgressSummary({
    required String clientId,
    required String trainerId,
    int periodDays = 28,
  }) async {
    final since = DateTime.now().subtract(Duration(days: periodDays));

    // Тренировки за период
    final bookings = await _client
        .from('bookings')
        .select('id, booking_state, scheduled_at')
        .eq('client_id', clientId)
        .eq('trainer_id', trainerId)
        .gte('scheduled_at', since.toIso8601String());

    final total = (bookings as List).length;
    final completed = bookings
        .where((b) => b['booking_state'] == 'completed')
        .length;

    // Чек-ины за период
    final checkins = await _client
        .from('retention_checkins')
        .select('wellbeing_score, created_at')
        .eq('client_id', clientId)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: true);

    final checkinList = (checkins as List);
    final scores = checkinList
        .map((c) => c['wellbeing_score'] as int)
        .toList();

    double? avgScore;
    int? firstScore;
    int? lastScore;
    if (scores.isNotEmpty) {
      avgScore = scores.reduce((a, b) => a + b) / scores.length;
      firstScore = scores.first;
      lastScore = scores.last;
    }

    // Базовое самочувствие из онбординга
    final onboarding = await getOnboarding(
      clientId: clientId,
      trainerId: trainerId,
    );

    return {
      'period_days': periodDays,
      'total_sessions': total,
      'completed_sessions': completed,
      'attendance_percent': total > 0 ? (completed / total * 100).round() : 0,
      'checkins_count': checkinList.length,
      'avg_wellbeing': avgScore,
      'first_wellbeing': firstScore,
      'last_wellbeing': lastScore,
      'base_wellbeing': onboarding?.baseWellbeing,
      'goal_type': onboarding?.goalType,
      'goal_description': onboarding?.goalDescription,
      'client_type': onboarding?.experienceType,
    };
  }
}
