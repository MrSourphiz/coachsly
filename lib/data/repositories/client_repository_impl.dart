import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/repositories/client_repository.dart';
import 'package:uuid/uuid.dart';
//import 'package:http/http.dart' as http;
//import 'dart:convert';

class ClientRepositoryImpl implements ClientRepository {
  final SupabaseClient supabaseClient;

  ClientRepositoryImpl(this.supabaseClient);

  @override
  Future<List<Client>> fetchClients(String trainerId) async {
    try {
      final response = await supabaseClient
          .from('telegram_clients')
          .select('id, telegram_user_id, trainer_id, first_name, last_name, created_at, updated_at')
          .eq('trainer_id', trainerId);

      print('ClientRepository: Raw response: $response');

      final clients = (response as List<dynamic>)
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();

      print('ClientRepository: Parsed clients: $clients');
      return clients;
    } catch (e) {
      print('ClientRepository: Error in fetchClients: $e');
      rethrow;
    }
  }

  @override
  Future<void> addNewClient(
      String trainerId, String name, String phoneNumber, {String? notes}) async {
    try {
      print('ClientRepository: Adding new client - trainerId: $trainerId, name: $name, phoneNumber: $phoneNumber, notes: $notes');
      const uuid = Uuid();
      final tempPassword = uuid.v4().substring(0, 8);
      final tempEmail = '${uuid.v4().substring(0, 8)}-client@coachsly.temp';

      // Вызов Edge Function через supabase.functions.invoke для создания пользователя
      final response = await supabaseClient.functions.invoke(
        'create-client-user',
        body: {
          'temp_email': tempEmail,
          'temp_password': tempPassword,
          'name': name,
          'phone_number': phoneNumber,
        },
      );

      print('ClientRepository: Edge Function response status: ${response.status}');
      print('ClientRepository: Edge Function response data: ${response.data}');

      if (response.status != 200) {
        throw Exception('Failed to create user: ${response.data}');
      }

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['error'] != null) {
        throw Exception('Edge Function error: ${responseData['error']}');
      }
      final clientId = responseData['client_id'] as String;

      // Добавление профиля клиента
      await supabaseClient.from('profiles_clients').insert({
        'id': clientId,
        'name': name,
        'phone_number': phoneNumber,
      });

      // Добавление клиента
      await supabaseClient.from('clients').insert({
        'trainer_id': trainerId,
        'client_id': clientId,
        'status': 'pending',
        'notes': notes,
      });

      print('ClientRepository: New client added - clientId: $clientId');
    } catch (e) {
      print('ClientRepository: Error in addNewClient: $e');
      rethrow;
    }
  }

  @override
  Future<String> createInvitation(String trainerId) async {
    try {
      print('ClientRepository: Creating invitation for trainerId: $trainerId');
      const uuid = Uuid();
      final token = uuid.v4();
      final response = await supabaseClient.from('client_invitations').insert({
        'trainer_id': trainerId,
        'token': token,
      }).select('token').single();
      print('ClientRepository: Invitation created - token: ${response['token']}');
      return response['token'] as String;
    } catch (e) {
      print('ClientRepository: Error in createInvitation: $e');
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
      print('ClientRepository: Invitation deleted');
    } catch (e) {
      print('ClientRepository: Error in deleteInvitation: $e');
      rethrow;
    }
  }

  @override
  Future<void> registerClientWithToken(String token, String name, String phoneNumber) async {
    try {
      print('ClientRepository: Registering client with token: $token, name: $name, phoneNumber: $phoneNumber');
      final invitation = await supabaseClient
          .from('client_invitations')
          .select()
          .eq('token', token)
          .eq('used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();
      if (invitation == null) {
        throw Exception('Invalid or expired invitation');
      }
      const uuid = Uuid();
      final tempPassword = uuid.v4().substring(0, 8);
      final email = '${uuid.v4().substring(0, 8)}@coachsly.temp';
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
      await supabaseClient.from('client_invitations').update({'used': true}).eq('token', token);
      print('ClientRepository: Client registered - clientId: ${user.id}');
    } catch (e) {
      print('ClientRepository: Error in registerClientWithToken: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateClientStatus(String clientId, String status) async {
    try {
      print('ClientRepository: Updating client status - clientId: $clientId, status: $status');
      await supabaseClient
          .from('clients')
          .update({'status': status})
          .eq('id', clientId); // Предполагаем, что clientId - это id в таблице clients
    } catch (e) {
      print('ClientRepository: Error in updateClientStatus: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteClient(String clientId) async {
    try {
      print('ClientRepository: Deleting client - clientId: $clientId');
      await supabaseClient
          .from('clients')
          .delete()
          .eq('id', clientId); // Предполагаем, что clientId - это id в таблице clients
    } catch (e) {
      print('ClientRepository: Error in deleteClient: $e');
      rethrow;
    }
  }
}