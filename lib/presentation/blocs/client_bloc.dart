import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/repositories/client_repository.dart';

abstract class ClientEvent {}

class FetchClients extends ClientEvent {
  final String trainerId;
  FetchClients(this.trainerId);
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

  const InvitationCreated(this.invitationUrl);

  @override
  List<Object?> get props => [invitationUrl];
}

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  final ClientRepository clientRepository;

  ClientBloc({required this.clientRepository}) : super(const ClientInitial()) {
    on<FetchClients>((event, emit) async {
      try {
        emit(const ClientLoading());
        final clients = await clientRepository.fetchClients(event.trainerId);
        emit(ClientLoaded(clients));
      } catch (e) {
        emit(ClientError('Ошибка загрузки клиентов: $e'));
      }
    });

    on<AddNewClient>((event, emit) async {
      try {
        print('ClientBloc: Adding new client - trainerId: ${event.trainerId}, firstName: ${event.name}');
        await clientRepository.addNewClient(
          event.trainerId,
          event.name,
          event.phoneNumber,
          notes: event.notes,
        );
        print('ClientBloc: Client added successfully');
        emit(const ClientLoading());
        add(FetchClients(event.trainerId));
      } catch (e) {
        print('ClientBloc: Error in AddNewClient: $e');
        emit(ClientError('Ошибка добавления клиента: ${e.toString()}'));
      }
    });

    on<CreateInvitation>((event, emit) async {
      try {
        print('ClientBloc: Creating invitation for trainerId: ${event.trainerId}');
        final botUsername = 'coachsly_bot';
        final token = await clientRepository.createInvitation(event.trainerId);
        final invitationUrl = 'https://t.me/$botUsername?start=$token';
        emit(InvitationCreated(invitationUrl));
      } catch (e) {
        print('ClientBloc: Error in CreateInvitation: $e');
        emit(const ClientError('Ошибка создания приглашения'));
      }
    });

    on<DeleteInvitation>((event, emit) async {
      try {
        String url = event.token;
        String token = url.split('=').last;
        print('ClientBloc: Deleting invitation token: ${token}');
        await clientRepository.deleteInvitation(token);
      } catch (e) {
        print('ClientBloc: Error in DeleteInvitation: $e');
        emit(const ClientError('Ошибка удаления приглашения'));
      }
    });

    on<UpdateClientStatus>((event, emit) async {
      try {
        print('ClientBloc: Updating client status - clientId: ${event.clientId}, status: ${event.status}');
        await clientRepository.updateClientStatus(event.clientId.toString(), event.status);
        emit(const ClientLoading());
        add(FetchClients(event.trainerId));
      } catch (e) {
        print('ClientBloc: Error in UpdateClientStatus: $e');
        emit(ClientError('Ошибка обновления статуса: ${e.toString()}'));
      }
    });

    on<DeleteClient>((event, emit) async {
      try {
        print('ClientBloc: Deleting client - clientId: ${event.clientId}');
        await clientRepository.deleteClient(event.clientId.toString());
        emit(const ClientLoading());
        add(FetchClients(event.trainerId));
      } catch (e) {
        print('ClientBloc: Error in DeleteClient: $e');
        emit(ClientError('Ошибка удаления клиента: ${e.toString()}'));
      }
    });
  }
}