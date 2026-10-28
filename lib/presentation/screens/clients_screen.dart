import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/core/constants/messenger.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/presentation/blocs/client_bloc.dart';
import 'package:formeo/presentation/blocs/retention_bloc.dart';
import 'package:formeo/presentation/blocs/schedule_bloc.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/ui/widgets/custom_app_bar.dart';
import 'package:formeo/ui/widgets/invitation_qr_card.dart';
import 'package:formeo/ui/widgets/universal_card.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late final ClientBloc clientBloc;
  late final String trainerId;

  String _statusFilter = 'active';
  String _sessionTypeFilter = 'all';
  bool _invitationDialogShown = false;

  @override
  void initState() {
    super.initState();
    final userProvider = GetIt.instance<UserProvider>();
    final user = userProvider.user;
    if (user != null) {
      trainerId = user.id;
      clientBloc = GetIt.instance<ClientBloc>();

      // ✅ ИСПРАВЛЕНИЕ: запускаем подписку только если данных ещё нет.
      // Если пользователь вернулся на экран — используем уже живой стрим,
      // не создаём новый WebSocket.
      final currentState = clientBloc.state;
      if (currentState is! ClientLoaded) {
        clientBloc.add(SubscribeClients(trainerId));
      }
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
            padding: EdgeInsets.only(
                bottom: navBarHeight + bottomPadding + 70.0),
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
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: navBarHeight + bottomPadding + 70.0),
                child: StreamBuilder<ClientState>(
                  stream: clientBloc.stream,
                  initialData: clientBloc.state,
                  builder: (context, snapshot) {
                    final state = snapshot.data;

                    if (state is InvitationCreated) {
                      if (!_invitationDialogShown) {
                        _invitationDialogShown = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showInvitationDialog(
                              context, _tokenFromUrl(state.invitationUrl), clientBloc);
                        });
                      }
                      return _buildClientsListOrOtherStates(
                          context, ClientLoaded(state.clients), clientBloc, trainerId);
                    }

                    return _buildClientsListOrOtherStates(
                        context, state, clientBloc, trainerId);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: () => clientBloc.add(CreateInvitation(trainerId)),
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusChip('Активные', 'active'),
              const SizedBox(width: 8),
              _statusChip('На паузе', 'paused'),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _typeChip('Все типы', 'all'),
                const SizedBox(width: 8),
                _typeChip('Разовые', 'single'),
                const SizedBox(width: 8),
                _typeChip('Абонемент', 'subscription'),
                const SizedBox(width: 8),
                _typeChip('Блок', 'block'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
            isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, String value) {
    final isSelected = _sessionTypeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _sessionTypeFilter = value),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
            isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
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
      var clients = state.clients;

      clients =
          clients.where((c) => c.status == _statusFilter).toList();

      if (_sessionTypeFilter != 'all') {
        clients = clients
            .where((c) => c.defaultSessionType == _sessionTypeFilter)
            .toList();
      }

      if (clients.isEmpty) {
        final isFiltered = _statusFilter != 'active' ||
            _sessionTypeFilter != 'all';

        if (isFiltered) {
          return Center(
            child: Text(
              'Нет клиентов по выбранному фильтру',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return _buildEmptyState(context);
      }

      return _buildClientsList(context, clients, trainerId);
    } else if (state is ClientError) {
      return Center(
        child: Text(
          state.message,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return Center(
      child: Text(
        'Инициализация...',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  /// Список клиентов. Если у тренера включён механизм удержания
  /// (users.retention_enabled), дополнительно подгружаем активные
  /// retention-сигналы и подсвечиваем проблемных клиентов в карточке —
  /// тем же цветом, что и в client_details_screen (красный/жёлтый).
  /// Если механизм не включён — рисуем обычный список без лишнего запроса.
  Widget _buildClientsList(
      BuildContext context,
      List<Client> clients,
      String trainerId,
      ) {
    debugPrint('clients_screen: _buildClientsList вызван, trainerId=$trainerId, clients.length=${clients.length}');
    final trainer = GetIt.instance<UserProvider>().user;
    final retentionEnabled = trainer?.retentionEnabled ?? false;
    debugPrint('clients_screen: retentionEnabled=$retentionEnabled');

    if (!retentionEnabled) {
      return _buildClientsListView(context, clients, const {});
    }

    return BlocProvider(
      create: (_) => GetIt.instance<RetentionBloc>()
        ..add(LoadActiveSignalsEvent(trainerId)),
      child: BlocBuilder<RetentionBloc, RetentionState>(
        buildWhen: (prev, curr) =>
        curr is SignalsLoaded || curr is RetentionLoading || curr is RetentionError,
        builder: (context, state) {
          if (state is RetentionError) {
            // Не блокируем список из-за сбоя загрузки сигналов — просто
            // показываем клиентов без подсветки/сортировки и печатаем
            // причину в консоль, чтобы её можно было найти и исправить.
            debugPrint('RetentionBloc: не удалось загрузить сигналы удержания: ${state.message}');
            return _buildClientsListView(context, clients, const {});
          }

          final signalLevelByClientId = <String, String>{};
          if (state is SignalsLoaded) {
            // Временный диагностический лог — уберём после того как разберёмся,
            // почему сигнал не подсвечивается. Сравните client_id из сигнала
            // со списком id клиентов ниже.
            debugPrint(
              'RetentionBloc: trainerId=$trainerId, получено сигналов=${state.signals.length}, '
                  'client_id из сигналов=${state.signals.map((s) => "${s.clientId}(resolved=${s.isResolved},level=${s.signalLevel})").toList()}',
            );
            debugPrint(
              'clients_screen: id клиентов в текущем списке=${clients.map((c) => c.id).toList()}',
            );
            for (final signal in state.signals) {
              if (signal.isResolved) continue;
              final current = signalLevelByClientId[signal.clientId];
              // Если у клиента несколько активных сигналов — красный важнее жёлтого.
              if (current == null || (current != 'red' && signal.signalLevel == 'red')) {
                signalLevelByClientId[signal.clientId] = signal.signalLevel;
              }
            }
          }
          final sortedClients =
          _sortBySignalPriority(clients, signalLevelByClientId);
          return _buildClientsListView(context, sortedClients, signalLevelByClientId);
        },
      ),
    );
  }

  /// Приоритет сигнала для сортировки: чем меньше число — тем выше в списке.
  /// red (0) → yellow (1) → без сигнала (2). Внутри группы порядок клиентов
  /// не меняется (List.sort в Dart — не гарантированно стабилен, поэтому
  /// сортируем по индексу как вторичному ключу).
  int _signalPriority(String? level) {
    switch (level) {
      case 'red':
        return 0;
      case 'yellow':
        return 1;
      default:
        return 2;
    }
  }

  List<Client> _sortBySignalPriority(
      List<Client> clients,
      Map<String, String> signalLevelByClientId,
      ) {
    final indexed = clients.asMap().entries.toList();
    indexed.sort((a, b) {
      final priorityA = _signalPriority(signalLevelByClientId[a.value.id]);
      final priorityB = _signalPriority(signalLevelByClientId[b.value.id]);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      // Внутри одной группы сохраняем исходный порядок (по имени/дате из бэка).
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  Widget _buildClientsListView(
      BuildContext context,
      List<Client> clients,
      Map<String, String> signalLevelByClientId,
      ) {
    return ListView.builder(
      padding: const EdgeInsets.all(5),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return UniversalCardV2(
          item: client,
          retentionSignalLevel: signalLevelByClientId[client.id],
          onTap: () => context.pushNamed(
            'clientDetails',
            extra: client,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline,
                    size: 40,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Клиентов пока нет',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Нажмите кнопку\u00a0+ в правом нижнем углу, чтобы создать ссылку-приглашение в Telegram или MAX и отправить её клиенту',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Добавить клиента',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Токен приглашения из ссылки вида https://t.me/<bot>?start=<token>.
  /// ClientBloc по-прежнему отдаёт готовую Telegram-ссылку — токен из неё
  /// подходит и для MAX, ссылку под выбранный мессенджер строит InvitationQrCard.
  String _tokenFromUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['start'] ?? url.split('=').last;
  }

  void _onInvitationDismissed(ClientBloc clientBloc) {
    _invitationDialogShown = false;
    final stateBeforeDismiss = clientBloc.state;
    clientBloc.add(DismissInvitation());
    // Расписание переподписываем только если были демо-клиенты —
    // их расписание нужно почистить после замены реальным клиентом.
    if (stateBeforeDismiss is InvitationCreated &&
        stateBeforeDismiss.clients.any((c) => c.isDemo)) {
      GetIt.instance<ScheduleBloc>().add(ResubscribeSchedules(trainerId));
    }
  }

  void _showInvitationDialog(
      BuildContext context,
      String token,
      ClientBloc clientBloc,
      ) {
    // Сразу копируем ссылку для последнего выбранного мессенджера
    final initialMessenger = InvitationQrCard.lastSelected;
    Clipboard.setData(ClipboardData(text: initialMessenger.inviteUrl(token)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ссылка для ${initialMessenger.label} скопирована в буфер обмена'),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Приглашение'),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: InvitationQrCard(
                token: token,
                style: InvitationCardStyle.themed,
                qrSize: 190,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _onInvitationDismissed(clientBloc);
              },
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    ).then((_) {
      // Только для закрытия через тап на barrier (вне диалога).
      // Небольшая задержка чтобы не конфликтовать с кнопкой Закрыть.
      Future.microtask(() {
        if (clientBloc.state is InvitationCreated) {
          _onInvitationDismissed(clientBloc);
        }
      });
    });
  }
}
