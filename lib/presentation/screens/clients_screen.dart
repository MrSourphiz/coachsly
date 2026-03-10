import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:coachsly/presentation/blocs/client_bloc.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';
import 'package:coachsly/ui/widgets/custom_app_bar.dart';
import 'package:coachsly/ui/widgets/universal_card.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late final ClientBloc clientBloc;
  late final String trainerId;

  @override
  void initState() {
    super.initState();

    final userProvider = GetIt.instance<UserProvider>();
    final user = userProvider.user;

    if (user != null) {
      trainerId = user.id;
      clientBloc = GetIt.instance<ClientBloc>();
      clientBloc.add(FetchClients(trainerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = GetIt.instance<UserProvider>();
    final user = userProvider.user;
    final double navBarHeight = 70.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    if (user == null) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: navBarHeight + bottomPadding + 70.0),
            child: Center(
              child: Text(
                'Пользователь не авторизован',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: 'Мои клиенты',
        trainerId: trainerId,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: navBarHeight + bottomPadding + 70.0),
          child: StreamBuilder<ClientState>(
            stream: clientBloc.stream,
            initialData: clientBloc.state,
            builder: (context, snapshot) {
              final state = snapshot.data;

              if (state is InvitationCreated) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showInvitationDialog(context, state.invitationUrl, clientBloc);
                  clientBloc.add(FetchClients(trainerId)); // сброс состояния
                });
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                );
              }

              return _buildClientsListOrOtherStates(context, state, clientBloc, trainerId);
            },
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: () {
            clientBloc.add(CreateInvitation(trainerId));
          },
          child: const Icon(Icons.add),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildClientsListOrOtherStates(
      BuildContext context,
      ClientState? state,
      ClientBloc clientBloc,
      String trainerId,
      ) {
    if (state is ClientLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    } else if (state is ClientLoaded) {
      final clients = state.clients;
      if (clients.isEmpty) {
        return Center(
          child: Text('Нет клиентов', style: Theme.of(context).textTheme.bodyLarge),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(5),
        itemCount: clients.length,
        itemBuilder: (context, index) {
          final client = clients[index];
          return UniversalCardV2(
            item: client,
            onTap: () => context.pushNamed(
              'clientDetails',
              extra: client,
            ),
          );
        },
      );
    } else if (state is ClientError) {
      return Center(
        child: Text(state.message, style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return Center(child: Text('Инициализация...', style: Theme.of(context).textTheme.bodyLarge));
  }

  void _showInvitationDialog(BuildContext context, String invitationUrl, ClientBloc clientBloc) {
    Clipboard.setData(ClipboardData(text: invitationUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована в буфер обмена')),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Приглашение'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: invitationUrl,
                    version: QrVersions.auto,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  invitationUrl,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Отправить в соцсеть'),
                  onPressed: () {
                    Share.share(invitationUrl);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                clientBloc.add(DeleteInvitation(invitationUrl));
                Navigator.of(context).pop();
              },
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );
  }
}
