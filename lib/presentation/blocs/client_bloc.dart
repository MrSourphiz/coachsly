import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';

abstract class ClientEvent {}

class FetchClients extends ClientEvent {
  final String trainerId;
  FetchClients(this.trainerId);
}

class SubscribeClients extends ClientEvent {
  final String trainerId;
  SubscribeClients(this.trainerId);
}

// Тихая переподписка при возврате из фона — без ClientLoading на экране
class ResubscribeClients extends ClientEvent {
  final String trainerId;
  ResubscribeClients(this.trainerId);
}

class AddClient extends ClientEvent {
  final String trainerId;
  final String name;
  final String? notes;
  AddClient(this.trainerId, this.name, {this.notes});
}

class AddNewClient extends ClientEvent {
  final String trainerId;
  final String name;
  final String phoneNumber;
  final String? notes;
  AddNewClient(this.trainerId, this.name, this.phoneNumber, {this.notes});
}

class CreateInvitation extends ClientEvent {
  final String trainerId;
  CreateInvitation(this.trainerId);
}

// Сбрасывает InvitationCreated → ClientLoaded после закрытия диалога.
// Без этого StreamBuilder остаётся в состоянии InvitationCreated
// и продолжает показывать спиннер.
class DismissInvitation extends ClientEvent {}

class DeleteInvitation extends ClientEvent {
  final String token;
  DeleteInvitation(this.token);
}

class UpdateClientStatus extends ClientEvent {
  final String clientId;
  final String status;
  final String trainerId;
  UpdateClientStatus(this.clientId, this.status, this.trainerId);
}

class DeleteClient extends ClientEvent {
  final String clientId;
  final String trainerId;
  DeleteClient(this.clientId, this.trainerId);
}

abstract class ClientState extends Equatable {
  const ClientState();

  @override
  List<Object?> get props => [];
}

class ClientInitial extends ClientState {
  const ClientInitial();
}

class ClientLoading extends ClientState {
  const ClientLoading();
}

class ClientLoaded extends ClientState {
  final List<Client> clients;

  const ClientLoaded(this.clients);

  @override
  List<Object?> get props => [clients];
}

class ClientError extends ClientState {
  final String message;

  const ClientError(this.message);

  @override
  List<Object?> get props => [message];
}

class InvitationCreated extends ClientState {
  final String invitationUrl;
  // Список клиентов на момент создания приглашения —
  // экран показывает их пока открыт диалог, не спиннер.
  final List<Client> clients;

  const InvitationCreated(this.invitationUrl, {this.clients = const []});

  @override
  List<Object?> get props => [invitationUrl, clients];
}

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  final ClientRepository clientRepository;

  // Guard от двойного запуска подписки (resume, token refresh).
  bool _subscriptionActive = false;
  String? _subscribedTrainerId;

  ClientBloc({required this.clientRepository}) : super(const ClientInitial()) {
    on<FetchClients>(_onFetchClients);
    on<SubscribeClients>(_onSubscribeClients);
    on<ResubscribeClients>(_onResubscribeClients);
    on<AddNewClient>(_onAddNewClient);
    on<CreateInvitation>(_onCreateInvitation);
    on<DismissInvitation>(_onDismissInvitation);
    on<DeleteInvitation>(_onDeleteInvitation);
    on<UpdateClientStatus>(_onUpdateClientStatus);
    on<DeleteClient>(_onDeleteClient);
  }

  Future<void> _onFetchClients(
      FetchClients event,
      Emitter<ClientState> emit,
      ) async {
    try {
      emit(const ClientLoading());
      final clients = await clientRepository.fetchClients(event.trainerId);
      emit(ClientLoaded(clients));
    } catch (e) {
      emit(ClientError('Ошибка загрузки клиентов: $e'));
    }
  }

  Future<void> _onSubscribeClients(
      SubscribeClients event,
      Emitter<ClientState> emit,
      ) async {
    if (_subscriptionActive && _subscribedTrainerId == event.trainerId) {
      debugPrint(
          'ClientBloc: subscription already active for ${event.trainerId}, skipping');
      return;
    }

    _subscriptionActive = true;
    _subscribedTrainerId = event.trainerId;

    if (state is! ClientLoaded) {
      emit(const ClientLoading());
    }

    const maxRetries = 3;
    int attempt = 0;

    try {
      while (!emit.isDone) {
        try {
          await emit.forEach(
            clientRepository.subscribeClients(event.trainerId),
            onData: (List<Client> clients) {
              attempt = 0;
              debugPrint(
                  'ClientBloc: subscribeClients update: ${clients.length} clients');

              // Если предыдущий список содержал демо, а новый — нет,
              // значит реальный клиент добавлен → переподписываем расписание.
              final prevState = state;
              if (prevState is ClientLoaded) {
                final hadDemo = prevState.clients.any((c) => c.isDemo);
                final hasDemo = clients.any((c) => c.isDemo);
                if (hadDemo && !hasDemo && clients.isNotEmpty) {
                  debugPrint(
                      'ClientBloc: demo → real transition, resubscribing schedules');
                  Future.microtask(() {
                    try {
                      final scheduleBloc = GetIt.instance<ScheduleBloc>();
                      scheduleBloc.add(ResubscribeSchedules(event.trainerId));
                    } catch (e) {
                      debugPrint('ClientBloc: scheduleBloc not found: $e');
                    }
                  });
                }
              }

              return ClientLoaded(clients);
            },
            onError: (error, _) {
              debugPrint('ClientBloc: SubscribeClients stream error: $error');
              return state is ClientLoaded
                  ? state as ClientLoaded
                  : const ClientLoading();
            },
          );
          break;
        } catch (e) {
          attempt++;
          debugPrint(
              'ClientBloc: SubscribeClients catch attempt $attempt: $e');

          if (attempt >= maxRetries) {
            debugPrint('ClientBloc: SubscribeClients max retries reached');
            emit(ClientError('Ошибка подписки на клиентов: $e'));
            return;
          }

          final delay = Duration(seconds: attempt * 2);
          debugPrint('ClientBloc: retry in ${delay.inSeconds}s');
          await Future.delayed(delay);

          if (!emit.isDone && state is! ClientLoaded) {
            emit(const ClientLoading());
          }
        }
      }
    } finally {
      _subscriptionActive = false;
      debugPrint('ClientBloc: subscription ended, flag reset');
    }
  }

  Future<void> _onResubscribeClients(
      ResubscribeClients event,
      Emitter<ClientState> emit,
      ) async {
    debugPrint('ClientBloc: silent resubscribe for ${event.trainerId}');
    _subscriptionActive = false;
    _subscribedTrainerId = null;
    await _onSubscribeClients(SubscribeClients(event.trainerId), emit);
  }

  Future<void> _onAddNewClient(
      AddNewClient event,
      Emitter<ClientState> emit,
      ) async {
    try {
      debugPrint(
          'ClientBloc: Adding new client - trainerId: ${event.trainerId}, firstName: ${event.name}');
      await clientRepository.addNewClient(
        event.trainerId,
        event.name,
        event.phoneNumber,
        notes: event.notes,
      );
      debugPrint('ClientBloc: Client added successfully');
    } catch (e) {
      debugPrint('ClientBloc: Error in AddNewClient: $e');
      emit(ClientError('Ошибка добавления клиента: ${e.toString()}'));
    }
  }

  Future<void> _onCreateInvitation(
      CreateInvitation event,
      Emitter<ClientState> emit,
      ) async {
    try {
      debugPrint(
          'ClientBloc: Creating invitation for trainerId: ${event.trainerId}');
      const botUsername = 'formeo_crm_bot';
      final token = await clientRepository.createInvitation(event.trainerId);
      final invitationUrl = 'https://t.me/$botUsername?start=$token';
      // Сохраняем текущий список клиентов в состоянии —
      // экран отобразит его пока открыт диалог приглашения.
      final currentClients = state is ClientLoaded
          ? (state as ClientLoaded).clients
          : <Client>[];
      emit(InvitationCreated(invitationUrl, clients: currentClients));
    } catch (e) {
      debugPrint('ClientBloc: Error in CreateInvitation: $e');
      emit(const ClientError('Ошибка создания приглашения'));
    }
  }

  void _onDismissInvitation(
      DismissInvitation event,
      Emitter<ClientState> emit,
      ) {
    // Если poll успел обновить состояние до ClientLoaded пока был открыт диалог
    // — список уже актуальный, ничего не делаем.
    if (state is ClientLoaded) {
      debugPrint(
          'ClientBloc: DismissInvitation — состояние уже ClientLoaded(${(state as ClientLoaded).clients.length}), пропускаем');
      return;
    }

    final clients = state is InvitationCreated
        ? (state as InvitationCreated).clients
        : <Client>[];

    final hasDemo = clients.any((c) => c.isDemo);

    if (hasDemo) {
      // Снимок содержит демо-клиентов — он устарел (poll ещё не успел обновить состояние).
      // Делаем рефетч чтобы получить актуальный список.
      debugPrint('ClientBloc: DismissInvitation — снимок с демо, перезапрашиваем');
      if (_subscribedTrainerId != null) {
        add(ResubscribeClients(_subscribedTrainerId!));
      }
    } else {
      // Все клиенты реальные — восстанавливаем снимок мгновенно,
      // чтобы список не мигал пока стрим не пришлёт обновление.
      debugPrint(
          'ClientBloc: DismissInvitation — восстанавливаем ${clients.length} клиентов');
      emit(ClientLoaded(clients));
    }
  }

  Future<void> _onDeleteInvitation(
      DeleteInvitation event,
      Emitter<ClientState> emit,
      ) async {
    try {
      final url = event.token;
      final token = url.split('=').last;
      debugPrint('ClientBloc: Deleting invitation token: $token');
      await clientRepository.deleteInvitation(token);
    } catch (e) {
      debugPrint('ClientBloc: Error in DeleteInvitation: $e');
      emit(const ClientError('Ошибка удаления приглашения'));
    }
  }

  Future<void> _onUpdateClientStatus(
      UpdateClientStatus event,
      Emitter<ClientState> emit,
      ) async {
    try {
      debugPrint(
          'ClientBloc: Updating client status - clientId: ${event.clientId}, status: ${event.status}');
      await clientRepository.updateClientStatus(
          event.clientId.toString(), event.status);
    } catch (e) {
      debugPrint('ClientBloc: Error in UpdateClientStatus: $e');
      emit(ClientError('Ошибка обновления статуса: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteClient(
      DeleteClient event,
      Emitter<ClientState> emit,
      ) async {
    try {
      debugPrint('ClientBloc: Deleting client - clientId: ${event.clientId}');
      await clientRepository.deleteClient(event.clientId.toString());
    } catch (e) {
      debugPrint('ClientBloc: Error in DeleteClient: $e');
      emit(ClientError('Ошибка удаления клиента: ${e.toString()}'));
    }
  }
}
