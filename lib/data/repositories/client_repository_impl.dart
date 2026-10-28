import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:uuid/uuid.dart';

class ClientRepositoryImpl implements ClientRepository {
  final SupabaseClient supabaseClient;

  ClientRepositoryImpl(this.supabaseClient);

  static const _clientSelect =
      'id, telegram_user_id, trainer_id, first_name, last_name, '
      'username, created_at, updated_at, default_session_type, status, '
      'notes, fatsecret_enabled, is_demo';

  @override
  Future<List<Client>> fetchClients(String trainerId) async {
    try {
      final response = await supabaseClient
          .from('telegram_clients')
          .select(_clientSelect)
          .eq('trainer_id', trainerId);

      debugPrint('ClientRepository: Raw response: $response');

      final clients = (response as List<dynamic>)
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('ClientRepository: Parsed clients: $clients');
      return clients;
    } catch (e) {
      debugPrint('ClientRepository: Error in fetchClients: $e');
      rethrow;
    }
  }

  @override
  Future<void> addNewClient(
      String trainerId, String name, String phoneNumber, {String? notes}) async {
    try {
      debugPrint('ClientRepository: Adding new client - trainerId: $trainerId, name: $name, phoneNumber: $phoneNumber, notes: $notes');
      const uuid = Uuid();
      final tempPassword = uuid.v4().substring(0, 8);
      final tempEmail = '${uuid.v4().substring(0, 8)}-client@formeo.temp';

      final response = await supabaseClient.functions.invoke(
        'create-client-user',
        body: {
          'temp_email': tempEmail,
          'temp_password': tempPassword,
          'name': name,
          'phone_number': phoneNumber,
        },
      );

      debugPrint('ClientRepository: Edge Function response status: ${response.status}');
      debugPrint('ClientRepository: Edge Function response data: ${response.data}');

      if (response.status != 200) {
        throw Exception('Failed to create user: ${response.data}');
      }

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['error'] != null) {
        throw Exception('Edge Function error: ${responseData['error']}');
      }
      final clientId = responseData['client_id'] as String;

      await supabaseClient.from('profiles_clients').insert({
        'id': clientId,
        'name': name,
        'phone_number': phoneNumber,
      });

      await supabaseClient.from('clients').insert({
        'trainer_id': trainerId,
        'client_id': clientId,
        'status': 'pending',
        'notes': notes,
      });

      debugPrint('ClientRepository: New client added - clientId: $clientId');
    } catch (e) {
      debugPrint('ClientRepository: Error in addNewClient: $e');
      rethrow;
    }
  }

  @override
  Future<String> createInvitation(String trainerId) async {
    try {
      debugPrint('ClientRepository: Creating invitation for trainerId: $trainerId');
      const uuid = Uuid();
      final token = uuid.v4();
      final expiresAt = DateTime.now().toUtc().add(const Duration(days: 365));
      final response = await supabaseClient.from('client_invitations').insert({
        'trainer_id': trainerId,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
      }).select('token').single();
      debugPrint('ClientRepository: Invitation created - token: ${response['token']}');
      return response['token'] as String;
    } catch (e) {
      debugPrint('ClientRepository: Error in createInvitation: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteInvitation(String token) async {
    try {
      await supabaseClient
          .from('client_invitations')
          .delete()
          .eq('token', token);
      debugPrint('ClientRepository: Invitation deleted');
    } catch (e) {
      debugPrint('ClientRepository: Error in deleteInvitation: $e');
      rethrow;
    }
  }

  @override
  Future<void> registerClientWithToken(String token, String name, String phoneNumber) async {
    try {
      debugPrint('ClientRepository: Registering client with token: $token, name: $name, phoneNumber: $phoneNumber');

      final invitation = await supabaseClient
          .from('client_invitations')
          .select()
          .eq('token', token)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (invitation == null) {
        throw Exception('Invalid or expired invitation');
      }

      const uuid = Uuid();
      final tempPassword = uuid.v4().substring(0, 8);
      final email = '${uuid.v4().substring(0, 8)}@formeo.temp';
      final authResponse = await supabaseClient.auth.signUp(
        email: email,
        password: tempPassword,
        data: {
          'name': name,
          'phone_number': phoneNumber,
          'role': 'client',
        },
      );
      final user = authResponse.user;
      if (user == null) {
        throw Exception('Failed to create user');
      }
      await supabaseClient.from('profiles').insert({
        'id': user.id,
        'name': name,
        'phone_number': phoneNumber,
      });
      await addNewClient(invitation['trainer_id'] as String, name, phoneNumber);
      debugPrint('ClientRepository: Client registered - clientId: ${user.id}');
    } catch (e) {
      debugPrint('ClientRepository: Error in registerClientWithToken: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteClient(String clientId) async {
    try {
      debugPrint('ClientRepository: Deleting client - clientId: $clientId');
      await supabaseClient
          .from('clients')
          .delete()
          .eq('id', clientId);
    } catch (e) {
      debugPrint('ClientRepository: Error in deleteClient: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateClientSessionType(String clientId, String sessionType) async {
    try {
      await supabaseClient
          .from('telegram_clients')
          .update({'default_session_type': sessionType})
          .eq('id', clientId);
    } catch (error) {
      debugPrint('Не удалось обновить тип тренировки: $error');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getClientBookings(String clientId) async {
    try {
      final data = await supabaseClient
          .from('bookings')
          .select()
          .eq('client_id', clientId)
          .order('scheduled_at', ascending: false);
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить тренировки клиента: $error');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getClientPayments(String clientId) async {
    try {
      final data = await supabaseClient
          .from('payments')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить платежи клиента: $error');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getClientActiveBlock(String clientId) async {
    try {
      final data = await supabaseClient
          .from('training_blocks')
          .select()
          .eq('client_id', clientId)
          .eq('status', 'active')
          .maybeSingle();
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить блок клиента: $error');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getClientActiveSubscription(String clientId) async {
    try {
      final data = await supabaseClient
          .from('subscriptions')
          .select()
          .eq('client_id', clientId)
          .eq('status', 'active')
          .maybeSingle();
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить абонемент клиента: $error');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    try {
      final data = await supabaseClient
          .from('bookings')
          .select('scheduled_at')
          .eq('id', bookingId)
          .maybeSingle();
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить тренировку: $error');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getClientAllBlocks(String clientId) async {
    try {
      final data = await supabaseClient
          .from('training_blocks')
          .select()
          .eq('client_id', clientId)
          .order('purchased_at', ascending: false);
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить блоки клиента: $error');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getClientAllSubscriptions(String clientId) async {
    try {
      final data = await supabaseClient
          .from('subscriptions')
          .select()
          .eq('client_id', clientId)
          .order('purchased_at', ascending: false);
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить абонементы клиента: $error');
      rethrow;
    }
  }

  @override
  Future<void> updateClientStatus(String clientId, String status) async {
    try {
      await supabaseClient
          .from('telegram_clients')
          .update({'status': status})
          .eq('id', clientId);
    } catch (error) {
      debugPrint('Не удалось обновить статус клиента: $error');
      rethrow;
    }
  }

  @override
  Future<void> updateClientNotes(String clientId, String notes) async {
    try {
      await supabaseClient
          .from('telegram_clients')
          .update({'notes': notes})
          .eq('id', clientId); // ⚠️ было .eq('id', notes) — опечатка, поправил
    } catch (error) {
      debugPrint('Не удалось обновить заметки: $error');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getClientNutritionWeekly(String clientId) async {
    try {
      final data = await supabaseClient
          .from('client_nutrition_weekly')
          .select()
          .eq('client_id', clientId)
          .order('week_start', ascending: false);
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить данные питания: $error');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getTrainerPaymentDetails(String trainerId) async {
    try {
      final data = await supabaseClient
          .from('trainer_payment_details')
          .select('block_sessions, subscription_days, single_price, block_price, subscription_price, currency, phone_number, preferred_bank')
          .eq('trainer_id', trainerId)
          .maybeSingle();
      return data;
    } catch (error) {
      debugPrint('Не удалось загрузить настройки тренера: $error');
      return null;
    }
  }

  static const _dashboardCacheTtl = Duration(seconds: 60);
  final Map<String, (Map<String, dynamic>, DateTime)> _dashboardCache = {};

  @override
  Future<Map<String, dynamic>> getClientDashboard(String clientId) async {
    final cached = _dashboardCache[clientId];
    if (cached != null && DateTime.now().difference(cached.$2) < _dashboardCacheTtl) {
      debugPrint('getClientDashboard: cache hit for $clientId');
      return cached.$1;
    }

    try {
      final data = await supabaseClient
          .rpc('get_client_dashboard', params: {'p_client_id': clientId});

      final map = Map<String, dynamic>.from(data as Map);

      for (final key in ['next_booking', 'active_block', 'active_subscription']) {
        if (map[key] == null || map[key] == 'null' || map[key].toString() == 'null') {
          map[key] = null;
        }
      }

      _dashboardCache[clientId] = (map, DateTime.now());
      return map;
    } catch (error) {
      debugPrint('Не удалось загрузить dashboard клиента: $error');
      rethrow;
    }
  }

  @override
  void invalidateDashboardCache(String clientId) {
    _dashboardCache.remove(clientId);
    debugPrint('getClientDashboard: cache invalidated for $clientId');
  }

  @override
  Future<void> createBlock({
    required String trainerId,
    required String clientId,
    required int totalSessions,
  }) async {
    try {
      await supabaseClient.from('training_blocks').insert({
        'trainer_id': trainerId,
        'client_id': clientId,
        'total_sessions': totalSessions,
        'used_sessions': 0,
        'reserved_sessions': 0,
        'status': 'created',
        'purchased_at': DateTime.now().toIso8601String(),
      });
      debugPrint('ClientRepository: Block created - clientId: $clientId, totalSessions: $totalSessions');
    } catch (error) {
      debugPrint('ClientRepository: Error in createBlock: $error');
      rethrow;
    }
  }

  @override
  Future<void> createSubscription({
    required String trainerId,
    required String clientId,
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      final validFrom = DateTime(now.year, now.month, now.day);
      final validUntil = validFrom.add(Duration(days: days));

      await supabaseClient.from('subscriptions').insert({
        'trainer_id': trainerId,
        'client_id': clientId,
        'valid_from': validFrom.toIso8601String().split('T')[0],
        'valid_until': validUntil.toIso8601String().split('T')[0],
        'status': 'created',
        'purchased_at': now.toIso8601String(),
      });
      debugPrint('ClientRepository: Subscription created - clientId: $clientId, days: $days');
    } catch (error) {
      debugPrint('ClientRepository: Error in createSubscription: $error');
      rethrow;
    }
  }

  @override
  Future<bool> getFatsecretEnabled(String clientId) async {
    try {
      final data = await supabaseClient
          .from('telegram_clients')
          .select('fatsecret_enabled')
          .eq('id', clientId)
          .maybeSingle();
      return data?['fatsecret_enabled'] as bool? ?? true;
    } catch (e) {
      debugPrint('Не удалось получить fatsecret_enabled: $e');
      return true;
    }
  }

  @override
  Future<void> setFatsecretEnabled({
    required String clientId,
    required bool enabled,
  }) async {
    try {
      await supabaseClient
          .from('telegram_clients')
          .update({'fatsecret_enabled': enabled})
          .eq('id', clientId);
    } catch (e) {
      throw Exception('Ошибка обновления fatsecret_enabled: $e');
    }
  }

  @override
  Future<FatsecretPromptResult> triggerFatsecretConnectPrompt({
    required String clientId,
    required String trainerId,
  }) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'fatsecret-auth/prompt',
        body: {
          'client_id': clientId,
          'trainer_id': trainerId,
        },
      );

      debugPrint(
        'fatsecret-auth/prompt: status=${response.status}, data=${response.data}',
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      return FatsecretPromptResult(
        alreadyConnected: data['already_connected'] as bool? ?? false,
        sent: data['sent'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('triggerFatsecretConnectPrompt error: $e');
      // Тумблер уже сохранён — не мешаем ему, просто сообщаем об ошибке отправки.
      return FatsecretPromptResult(
        alreadyConnected: false,
        sent: false,
        error: e.toString(),
      );
    }
  }

  /// Подписка через Realtime channel + polling пока есть демо-клиенты.
  ///
  /// Realtime не публикует события от SECURITY DEFINER триггеров (бот пишет
  /// через service role). Поэтому пока в списке есть демо-клиенты — делаем
  /// poll каждые 4 сек. Но эмитим в стрим только если набор id изменился —
  /// UI не мигает при одинаковом списке.
  @override
  Stream<List<Client>> subscribeClients(String trainerId) async* {
    Future<List<Map<String, dynamic>>> fetchAll() => supabaseClient
        .from('telegram_clients')
        .select(_clientSelect)
        .eq('trainer_id', trainerId);

    final initial = await fetchAll();
    final cache = <String, Map<String, dynamic>>{};
    for (final row in initial) {
      cache[row['id'] as String] = row;
    }

    debugPrint('subscribeClients initial: ${cache.length} clients');
    yield cache.values.map((e) => Client.fromJson(e)).toList();

    final controller = StreamController<List<Client>>();

    bool hasDemo() => cache.values.any((r) => r['is_demo'] as bool? ?? false);

    void applyFresh(List<Map<String, dynamic>> fresh) {
      final freshIds = {for (final r in fresh) r['id'] as String};
      final changed = freshIds.length != cache.length ||
          !freshIds.containsAll(cache.keys);
      cache.clear();
      for (final r in fresh) {
        cache[r['id'] as String] = r;
      }
      if (changed && !controller.isClosed) {
        debugPrint('subscribeClients: list changed → ${cache.length} clients');
        controller.add(cache.values.map((e) => Client.fromJson(e)).toList());
      }
    }

    Timer? pollTimer;
    if (hasDemo()) {
      debugPrint('subscribeClients: demo present, starting 4s poll');
      pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        if (!hasDemo()) {
          pollTimer?.cancel();
          return;
        }
        try {
          applyFresh(await fetchAll());
          if (!hasDemo()) {
            debugPrint('subscribeClients: real client detected via poll, stopping');
            pollTimer?.cancel();
          }
        } catch (e) {
          debugPrint('subscribeClients: poll error $e');
        }
      });
    }

    final channel = supabaseClient
        .channel('clients:trainer:$trainerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'telegram_clients',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'trainer_id',
        value: trainerId,
      ),
      callback: (payload) {
        final eventType = payload.eventType;
        debugPrint('subscribeClients Realtime $eventType');

        if (eventType == PostgresChangeEvent.insert ||
            eventType == PostgresChangeEvent.update) {
          final row = payload.newRecord;
          final id = row['id'] as String?;
          if (id != null) {
            cache[id] = row;
            final isDemo = row['is_demo'] as bool? ?? false;
            if (!isDemo && eventType == PostgresChangeEvent.insert) {
              Future.microtask(() async {
                try {
                  applyFresh(await fetchAll());
                  pollTimer?.cancel();
                } catch (e) {
                  debugPrint('subscribeClients: refetch error $e');
                }
              });
              return;
            }
          }
        } else if (eventType == PostgresChangeEvent.delete) {
          final id = (payload.oldRecord['id'] ?? payload.newRecord['id']) as String?;
          if (id != null) cache.remove(id);
        }

        if (!controller.isClosed) {
          controller.add(cache.values.map((e) => Client.fromJson(e)).toList());
        }
      },
    ).subscribe();

    try {
      yield* controller.stream;
    } finally {
      pollTimer?.cancel();
      await channel.unsubscribe();
      await controller.close();
    }
  }
}
