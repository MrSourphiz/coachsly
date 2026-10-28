import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/repositories/client_repository.dart';
import 'package:formeo/domain/repositories/payment_repository.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/core/constants/messenger.dart';
import 'package:formeo/core/utils/download_helper.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/presentation/screens/retention_client_section.dart';
import 'package:formeo/domain/repositories/workout_log_repository.dart';
import 'package:formeo/domain/repositories/workout_plan_repository.dart';
import 'package:formeo/presentation/screens/body_measurements_section.dart';

// Внутренние идентификаторы вкладок экрана.
// «Удержание» и «Питание» видны только если у тренера
// включены соответствующие настройки (retention_enabled / fatsecret_needed
// в таблице users) — см. _resolveVisibleTabs().
enum _ClientTab { overview, retention, nutrition, measurements, workouts, history }

class ClientDetailsScreen extends StatefulWidget {
  final Client client;
  const ClientDetailsScreen({super.key, required this.client});
  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<_ClientTab> _tabs;
  late Client _client;
  bool _updatingSessionType = false;
  bool _updatingStatus = false;
  bool _editingNotes = false;
  bool _savingNotes = false;
  late TextEditingController _notesController;
  String _bookingsFilter = 'all';
  bool _creatingProduct = false;
  bool _productCreated = false;
  late Future<Map<String, dynamic>> _dashboardFuture;
  late Future<Map<String, dynamic>?> _trainerSettingsFuture;
  Future<List<Map<String, dynamic>>>? _bookingsFuture;
  Future<List<Map<String, dynamic>>>? _paymentsFuture;
  late Future<List<Map<String, dynamic>>> _subscriptionsFuture;
  late Future<List<Map<String, dynamic>>> _blocksFuture;
  late Future<List<Map<String, dynamic>>> _nutritionFuture;
  Future<List<Map<String, dynamic>>>? _workoutLogsFuture;
  Future<String?>? _activePlanNameFuture;
  final Map<String, Future<String>> _bookingDateFutureCache = {};
  late bool _fatsecretEnabled;

  final _sessionTypeLabels = {
    'single': 'Разовая тренировка',
    'subscription': 'Абонемент',
    'block': 'Блок тренировок',
  };

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _fatsecretEnabled = _client.fatsecretEnabled;
    _notesController = TextEditingController(text: _client.notes ?? '');

    _tabs = _resolveVisibleTabs();
    _tabController = TabController(length: _tabs.length, vsync: this);

    _initFutures();
  }

  /// Формирует список видимых вкладок на основе настроек тренера
  /// (текущего залогиненного пользователя — это всегда сам тренер,
  /// т.к. экран открывается только им для своих клиентов).
  /// «Удержание» видна только при users.retention_enabled == true.
  /// «Питание» видна только при users.fatsecret_needed == true.
  List<_ClientTab> _resolveVisibleTabs() {
    final trainer = GetIt.instance<UserProvider>().user;
    final retentionEnabled = trainer?.retentionEnabled ?? false;
    final fatsecretNeeded = trainer?.fatsecretNeeded ?? false;
    final isPro = trainer?.isPro ?? false;

    return [
      _ClientTab.overview,
      if (retentionEnabled || _client.isDemo) _ClientTab.retention,
      if (fatsecretNeeded || _client.isDemo) _ClientTab.nutrition,
      if (isPro || _client.isDemo) _ClientTab.measurements,
      if (isPro || _client.isDemo) _ClientTab.workouts,
      _ClientTab.history,
    ];
  }

  String _tabLabel(_ClientTab tab) {
    switch (tab) {
      case _ClientTab.overview:
        return 'Обзор';
      case _ClientTab.retention:
        return 'Удержание';
      case _ClientTab.nutrition:
        return 'Питание';
      case _ClientTab.measurements:
        return 'Замеры';
      case _ClientTab.workouts:
        return 'Тренировки';
      case _ClientTab.history:
        return 'История';
    }
  }

  Widget _buildTabContent(_ClientTab tab) {
    switch (tab) {
      case _ClientTab.overview:
        return _buildOverviewTab();
      case _ClientTab.retention:
        return _buildRetentionTab();
      case _ClientTab.nutrition:
        return _buildNutritionTab();
      case _ClientTab.measurements:
        return _buildMeasurementsTab();
      case _ClientTab.workouts:
        return _buildWorkoutsTab();
      case _ClientTab.history:
        return _buildHistoryTab();
    }
  }

  void _initFutures() {
    final repo = GetIt.instance<ClientRepository>();
    _dashboardFuture       = repo.getClientDashboard(_client.id);
    _trainerSettingsFuture = repo.getTrainerPaymentDetails(_client.trainerId);
    _nutritionFuture       = repo.getClientNutritionWeekly(_client.id);

    _subscriptionsFuture   = repo.getClientAllSubscriptions(_client.id);
    _blocksFuture          = repo.getClientAllBlocks(_client.id);

    if (_tabs.contains(_ClientTab.workouts)) {
      _workoutLogsFuture = GetIt.instance<WorkoutLogRepository>().getClientWorkoutLogs(_client.id);
      _activePlanNameFuture = GetIt.instance<WorkoutPlanRepository>().getActiveQuickPlanName(_client.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateSessionType(String newType) async {
    setState(() => _updatingSessionType = true);
    try {
      await GetIt.instance<ClientRepository>().updateClientSessionType(_client.id, newType);
      GetIt.instance<ClientRepository>().invalidateDashboardCache(_client.id);
      if (!mounted) return;
      setState(() {
        _client = _client.copyWith(defaultSessionType: newType);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тип тренировки обновлён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _updatingSessionType = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updatingStatus = true);
    try {
      await GetIt.instance<ClientRepository>().updateClientStatus(_client.id, newStatus);
      GetIt.instance<ClientRepository>().invalidateDashboardCache(_client.id);
      if (!mounted) return;
      setState(() {
        _client = _client.copyWith(status: newStatus);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatus == 'paused' ? 'Клиент поставлен на паузу' : 'Клиент снова активен'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    try {
      await GetIt.instance<ClientRepository>().updateClientNotes(_client.id, _notesController.text);
      if (!mounted) return;
      setState(() {
        _client = _client.copyWith(notes: _notesController.text);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заметки сохранены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _setFatsecretEnabled(bool value) async {
    final wasEnabled = _fatsecretEnabled;
    setState(() => _fatsecretEnabled = value);
    final repo = GetIt.instance<ClientRepository>();
    try {
      await repo.setFatsecretEnabled(
        clientId: _client.id,
        enabled: value,
      );

      // Активируем механизм только при включении (false -> true)
      if (value && !wasEnabled) {
        final result = await repo.triggerFatsecretConnectPrompt(
          clientId: _client.id,
          trainerId: _client.trainerId,
        );
        if (!mounted) return;
        final message = result.alreadyConnected
            ? 'FatSecret уже подключён у клиента'
            : result.sent
            ? 'Клиенту отправлено приглашение подключить FatSecret'
            : 'Клиент ещё не писал боту в ${_client.messenger.label} — приглашение придёт, как только он это сделает';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _fatsecretEnabled = wasEnabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('${_client.firstName} ${_client.lastName ?? ""} больше не будет отображаться в приложении.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GetIt.instance<ClientRepository>().updateClientStatus(_client.id, 'deleted');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  Future<void> _openMessenger() async {
    final url = _client.messenger.profileUrl(_client.username);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_client.isMax
            ? 'У клиента нет публичного ника в MAX — напишите ему через бота'
            : 'Username клиента не указан'),
      ));
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _createProduct() async {
    setState(() => _creatingProduct = true);
    try {
      final repo = GetIt.instance<ClientRepository>();
      final settings = await _trainerSettingsFuture;
      final isBlock = _client.defaultSessionType == 'block';
      final blockSessions = settings?['block_sessions'];
      final subscriptionDays = settings?['subscription_days'];
      final amount = isBlock
          ? (blockSessions is int ? blockSessions : null)
          : (subscriptionDays is int ? subscriptionDays : null);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          isBlock ? 'В настройках не задано количество тренировок в блоке'
              : 'В настройках не задан срок действия абонемента',
        )));
        return;
      }
      if (isBlock) {
        await repo.createBlock(trainerId: _client.trainerId, clientId: _client.id, totalSessions: amount);
      } else {
        await repo.createSubscription(trainerId: _client.trainerId, clientId: _client.id, days: amount);
      }
      setState(() {
        _blocksFuture        = repo.getClientAllBlocks(_client.id);
        _subscriptionsFuture = repo.getClientAllSubscriptions(_client.id);
        repo.invalidateDashboardCache(_client.id);
        _dashboardFuture     = repo.getClientDashboard(_client.id);
        _productCreated      = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка создания: $e')));
    } finally {
      if (mounted) setState(() => _creatingProduct = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      final repo = GetIt.instance<ClientRepository>();
      final bookings = await repo.getClientBookings(_client.id);
      final payments = await repo.getClientPayments(_client.id);
      final excel = ex.Excel.createExcel();
      final bookingsSheet = excel['История тренировок'];
      excel.setDefaultSheet('История тренировок');
      bookingsSheet.appendRow([
        ex.TextCellValue('Дата тренировки'), ex.TextCellValue('Тип тренировки'), ex.TextCellValue('Статус'),
      ]);
      final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
      for (final b in bookings) {
        final date = DateTime.parse(b['scheduled_at']).toLocal();
        bookingsSheet.appendRow([
          ex.TextCellValue(dateFormat.format(date)),
          ex.TextCellValue(_sessionTypeLabel(b['session_type'] ?? '')),
          ex.TextCellValue(_bookingStatusLabel(b['booking_state'] ?? '', b['confirmation_state'] ?? '')),
        ]);
      }
      final paymentsSheet = excel['История оплат'];
      final dateFormatShort = DateFormat('dd.MM.yyyy');
      paymentsSheet.appendRow([
        ex.TextCellValue('Дата оплаты'), ex.TextCellValue('Сумма'),
        ex.TextCellValue('Тип'), ex.TextCellValue('Статус оплаты'),
      ]);
      for (final p in payments) {
        final createdAt = DateTime.parse(p['created_at']).toLocal();
        paymentsSheet.appendRow([
          ex.TextCellValue(dateFormatShort.format(createdAt)),
          ex.TextCellValue('${p['amount']?.toString() ?? '—'} ₽'),
          ex.TextCellValue(_sessionTypeLabel(p['purchase_type'] ?? '')),
          ex.TextCellValue(_paymentStatusLabel(p['status'] ?? '')),
        ]);
      }
      excel.delete('Sheet1');
      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception('Не удалось создать файл');
      final fileName = 'client_${_client.firstName}_${_client.lastName ?? ''}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      if (kIsWeb) {
        downloadFile(fileBytes, fileName);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          text: 'История клиента ${_client.firstName} ${_client.lastName ?? ''}',
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  // ── Просмотр чека оплаты ──
  Future<void> _showReceipt(String storagePath) async {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: FutureBuilder<String?>(
          future: GetIt.instance<PaymentRepository>().getReceiptSignedUrl(storagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }
            final url = snapshot.data;
            if (snapshot.hasError || url == null || url.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('Не удалось загрузить чек',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ),
              );
            }
            return Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context, error, stack) => const SizedBox(
                      height: 200,
                      child: Center(child: Text('Ошибка загрузки изображения', style: TextStyle(color: Colors.white))),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_client.firstName} ${_client.lastName ?? ''}'),
        backgroundColor: AppColors.colorLightBlue,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            onSelected: (value) {
              switch (value) {
                case 'messenger':
                  _openMessenger();
                  break;
                case 'export':
                  _exportToExcel();
                  break;
                case 'delete':
                  _deleteClient();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'messenger',
                child: Row(
                  children: [
                    Icon(_client.messenger.icon, color: AppColors.colorBlue, size: 20),
                    const SizedBox(width: 10),
                    Text('Написать в ${_client.messenger.label}'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, color: AppColors.colorBlue, size: 20),
                    SizedBox(width: 10),
                    Text('Выгрузить в Excel'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 10),
                    Text('Удалить клиента', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.colorWhite,
          unselectedLabelColor: AppColors.colorWhite.withValues(alpha: 0.55),
          indicatorColor: AppColors.colorDarkRed,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: _tabs.map((t) => Tab(text: _tabLabel(t))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map(_buildTabContent).toList(),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSection(),
          const SizedBox(height: 24),
          if (_activePlanNameFuture != null) ...[
            _buildActivePlanSection(),
            const SizedBox(height: 24),
          ],
          _buildNextBookingSection(),
          const SizedBox(height: 24),
          _buildSessionTypeSection(),
          const SizedBox(height: 24),
          _buildNotesSection(),
        ],
      ),
    );
  }

  /// Название текущей назначенной клиенту быстрой программы тренировок.
  /// Секция видна только Pro-тренерам (та же фича, что и вкладка
  /// "Тренировки") — future заполняется в _initFutures только тогда.
  /// Если программа не назначена, показывается неброская заглушка,
  /// а не пустой блок, чтобы тренер понимал, что можно назначить программу.
  Widget _buildActivePlanSection() {
    return FutureBuilder<String?>(
      future: _activePlanNameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.colorLightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Загрузка программы тренировок...'),
              ],
            ),
          );
        }

        final planName = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.colorLightBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: planName != null
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: planName != null
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Программа тренировок',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 2),
                    Text(
                      planName ?? 'Не назначена',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: planName != null ? null : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetentionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showRetentionMechanismInfo(context),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Подробнее о механизме удержания'),
            ),
          ),
          const SizedBox(height: 4),
          RetentionAlertsBar(
            clientId: _client.id,
            trainerId: _client.trainerId,
            telegramUserId: _client.telegramUserId,
            clientCreatedAt: _client.createdAt,
            isDemo: _client.isDemo,
          ),
          const SizedBox(height: 16),
          RetentionProfileSection(
            clientId: _client.id,
            trainerId: _client.trainerId,
          ),
        ],
      ),
    );
  }

  /// Всплывающее окно с описанием механизма удержания — сжатая версия
  /// внутренней методологии (типы клиентов, стартовый опрос, система
  /// сигналов), без академических ссылок и экономики ROI — тренеру важно
  /// понимать логику работы, а не источники исследований.
  void _showRetentionMechanismInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF172554),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Как работает механизм удержания',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF9FAFB)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFF9FAFB)),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mechanismSection(
                        'Зачем это нужно',
                        'Большинство клиентов уходят молча — без конфликта и явной причины. '
                            'Чаще всего дело не в тренировках, а в том, что клиент перестаёт видеть '
                            'прогресс и связь с тренером ослабевает. Механизм помогает заметить это '
                            'вовремя и напомнить о себе до того, как клиент решит уйти.',
                      ),
                      _mechanismSection(
                        'Типы клиентов',
                        '🆕 Новичок — никогда не занимался или почти не занимался. Высокий риск '
                            'ухода без структуры и частых касаний.\n\n'
                            '💪 Опытный — регулярно тренируется, самомотивирован. Низкий риск, но '
                            'не любит лишний контроль — важно не мешать.\n\n'
                            '🔄 Йо-йо — уже бросал раньше, вернулся. Самый высокий риск повторного '
                            'ухода — важно понять причину прошлого отказа и не пускать на самотёк.',
                      ),
                      _mechanismSection(
                        'Стартовый опрос',
                        'При первом контакте с ботом клиент проходит короткий опрос (около '
                            '3 минут): цель тренировок, прошлый опыт, нужный уровень поддержки и '
                            'текущее самочувствие по шкале 1–5. Результаты видите только вы — они '
                            'формируют профиль клиента и точку отсчёта для отслеживания прогресса. '
                            'Клиент получает одно персональное сообщение-отклик после опроса.',
                      ),
                      _mechanismSection(
                        'Система сигналов',
                        '🔴 Красный — два пропуска подряд или низкая оценка самочувствия дважды '
                            'подряд. Уведомление приходит немедленно — нужен личный контакт с клиентом.\n\n'
                            '🟡 Жёлтый — посещаемость упала ниже половины от плана за 2 недели. Стоит '
                            'написать клиенту и уточнить, что происходит.\n\n'
                            '🟢 Зелёный — посещаемость стабильна, оценки не падают. Хороший момент '
                            'предложить следующий блок тренировок или абонемент.',
                      ),
                      _mechanismSection(
                        'Прогресс-срез',
                        'Раз в 2–4 недели клиент получает сводку: количество тренировок за период, '
                            'динамика самочувствия, при подключённом FatSecret — данные по питанию. '
                            'Отдельный дневник вести не нужно — платформа собирает срез из уже '
                            'имеющихся данных бронирований и опросов самочувствия.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mechanismSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF9FAFB)),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 13, height: 1.45, color: const Color(0xFFF9FAFB).withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: BodyMeasurementsSection(
        clientId: _client.id,
        isDemo: _client.isDemo,
      ),
    );
  }

  Widget _buildNutritionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FatsecretToggle(
            enabled: _fatsecretEnabled,
            onChanged: _setFatsecretEnabled,
          ),
          if (_fatsecretEnabled) ...[
            const SizedBox(height: 12),
            _buildNutritionScheduleBanner(),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _nutritionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Ошибка: ${snapshot.error}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  );
                }
                final records = List<Map<String, dynamic>>.from(snapshot.data ?? []);
                records.sort((a, b) => (b['week_start'] as String).compareTo(a['week_start'] as String));
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Нет данных о питании',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                  );
                }
                return _buildNutritionByMonth(records);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionScheduleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.colorWhite.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Данные по питанию запрашиваются автоматически каждый понедельник — '
                  'свежий отчёт за прошедшую неделю появится здесь в этот день',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.colorWhite.withValues(alpha: 0.55),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _workoutLogsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ошибка: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            );
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Пока нет истории тренировок',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: logs.map((log) => _buildWorkoutLogCard(log)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutLogCard(Map<String, dynamic> log) {
    final performedAt = DateTime.parse(log['performed_at'] as String);
    final dayOfWeek = (log['day_of_week'] as int? ?? 0).clamp(0, 6);
    final status = log['status'] as String? ?? 'in_progress';
    final setsRaw = log['workout_log_sets'] as List? ?? [];

    // Группируем подходы по упражнению, сохраняя порядок из плана.
    // Заодно достаём метку дня (day_label) из первого попавшегося
    // упражнения — все подходы в рамках одной тренировки относятся
    // к одному и тому же дню программы, метка у них общая.
    final Map<String, List<Map<String, dynamic>>> byExercise = {};
    final Map<String, String> exerciseNames = {};
    final Map<String, int> exerciseOrder = {};
    String? dayLabel;
    for (final raw in setsRaw) {
      final s = Map<String, dynamic>.from(raw as Map);
      final exId = s['quick_plan_exercise_id'] as String;
      final exData = s['quick_plan_exercises'] as Map?;
      exerciseNames[exId] = exData?['custom_name'] as String? ?? 'Упражнение';
      exerciseOrder[exId] = exData?['exercise_order'] as int? ?? 0;
      dayLabel ??= exData?['day_label'] as String?;
      byExercise.putIfAbsent(exId, () => []).add(s);
    }
    final resolvedDayLabel = (dayLabel != null && dayLabel.trim().isNotEmpty)
        ? dayLabel
        : 'День ${dayOfWeek + 1}';
    final exerciseIds = byExercise.keys.toList()
      ..sort((a, b) => (exerciseOrder[a] ?? 0).compareTo(exerciseOrder[b] ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('dd.MM.yyyy').format(performedAt)} · $resolvedDayLabel',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.colorWhite),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (status == 'completed' ? const Color(0xFF4CAF50) : const Color(0xFFFF9800))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status == 'completed' ? 'Завершена' : 'В процессе',
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'completed' ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    ),
                  ),
                ),
              ],
            ),
            if (exerciseIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Подходы ещё не внесены',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
              )
            else ...[
              const SizedBox(height: 8),
              ...exerciseIds.map((exId) {
                final sets = byExercise[exId]!
                  ..sort((a, b) => (a['set_number'] as int).compareTo(b['set_number'] as int));
                final setsLabel = sets.map((s) {
                  final reps = s['reps_actual'];
                  final weight = s['weight_actual'];
                  if (reps == null && weight == null) return '—';
                  final weightStr = weight != null ? '${weight}кг' : '';
                  final repsStr = reps != null ? '×$reps' : '';
                  return '$weightStr$repsStr';
                }).join('  ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(exerciseNames[exId] ?? '',
                            style: const TextStyle(fontSize: 13, color: AppColors.colorWhite)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(setsLabel,
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection(),
          const SizedBox(height: 24),
          _buildBookingsSection(),
          const SizedBox(height: 16),
          _buildPaymentsSection(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.colorLightBlue),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _client.isPaused ? 'Клиент на паузе' : 'Клиент активен',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: _client.isPaused ? AppColors.colorRed : AppColors.colorWhite),
              ),
              const SizedBox(height: 2),
              Text(
                _client.isPaused ? 'Временно не занимается' : 'Занимается в штатном режиме',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
          _updatingStatus
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
            value: _client.isPaused,
            activeColor: Theme.of(context).colorScheme.error,
            onChanged: (val) => _updateStatus(val ? 'paused' : 'active'),
          ),
        ],
      ),
    );
  }

  Widget _buildNextBookingSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final next = snapshot.data?['next_booking'] as Map<String, dynamic>?;
        if (next == null) return const SizedBox.shrink();
        final date = DateTime.parse(next['scheduled_at'] as String).toLocal();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.colorLightBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.event, color: Theme.of(context).colorScheme.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ближайшая тренировка',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd.MM.yyyy HH:mm').format(date),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(_sessionTypeLabel(next['session_type'] as String? ?? ''),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionTypeSection() {
    final isBlock  = _client.defaultSessionType == 'block';
    final isSub    = _client.defaultSessionType == 'subscription';
    final isPaused = _client.isPaused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Текущий тип тренировок',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('_dashboardFuture error: ${snapshot.error}');
            }
            final loaded = snapshot.connectionState != ConnectionState.waiting
                && snapshot.data != null;
            final data         = snapshot.data;
            final hasScheduled = loaded ? (data!['has_scheduled'] as bool? ?? false) : false;
            final rawBlock  = loaded ? data!['active_block']         : null;
            final rawSub    = loaded ? data!['active_subscription']  : null;
            final activeBlock = (rawBlock  is Map) ? Map<String, dynamic>.from(rawBlock)  : null;
            final activeSub   = (rawSub    is Map) ? Map<String, dynamic>.from(rawSub)    : null;

            final hasActiveProduct = isPaused || hasScheduled ||
                (isBlock && activeBlock != null) || (isSub && activeSub != null);

            final lockReason = isPaused
                ? 'Смена типа недоступна — клиент на паузе'
                : hasScheduled
                ? 'Смена типа недоступна — есть запланированные тренировки с типом «${_sessionTypeLabels[_client.defaultSessionType] ?? _client.defaultSessionType}»'
                : isBlock
                ? 'Смена типа недоступна — активный блок тренировок'
                : 'Смена типа недоступна — активный абонемент';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  ignoring: hasActiveProduct || _updatingSessionType,
                  child: Opacity(
                    opacity: hasActiveProduct ? 0.5 : 1.0,
                    child: DropdownButtonFormField<String>(
                      value: _client.defaultSessionType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _sessionTypeLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null && val != _client.defaultSessionType) _updateSessionType(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!loaded) ...[
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ] else if (hasActiveProduct) ...[
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(lockReason,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isBlock && activeBlock != null) _buildActiveBlockInfo(activeBlock)
                  else if (isSub && activeSub != null) _buildActiveSubscriptionInfo(activeSub),
                ] else ...[
                  if (isBlock || isSub) _buildCreateProductForm(),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreateProductForm() {
    final isBlock = _client.defaultSessionType == 'block';
    return FutureBuilder<Map<String, dynamic>?>(
      future: _trainerSettingsFuture,
      builder: (context, snapshot) {
        final isLoading    = snapshot.connectionState == ConnectionState.waiting;
        final settings     = snapshot.data;
        final blockSessions    = settings?['block_sessions'];
        final subscriptionDays = settings?['subscription_days'];
        final amount = isBlock
            ? (blockSessions    is int ? blockSessions    : null)
            : (subscriptionDays is int ? subscriptionDays : null);
        final hasSettings = amount != null && amount > 0;

        if (_productCreated) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF4CAF50)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBlock ? 'Блок успешно создан!' : 'Абонемент успешно создан!',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50)),
                      ),
                      const SizedBox(height: 2),
                      Text('Клиент уже уведомлен',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.colorLightBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    isBlock ? 'Нет активного блока тренировок' : 'Нет активного абонемента',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (!hasSettings)
                Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 14, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isBlock ? 'Задайте количество тренировок в блоке в настройках'
                            : 'Задайте срок действия абонемента в настройках',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isBlock ? '$amount тренировок' : '$amount дней',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
                          Text('из настроек тренера',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _creatingProduct ? null : _createProduct,
                        icon: _creatingProduct
                            ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.colorWhite))
                            : const Icon(Icons.add, size: 16),
                        label: Text(isBlock ? 'Добавить блок' : 'Добавить абонемент'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colorDarkRed,
                          foregroundColor: AppColors.colorWhite,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          textStyle: const TextStyle(fontSize: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats       = snapshot.data?['stats'] as Map<String, dynamic>? ?? {};
        final total       = (stats['total']          as num?)?.toInt()    ?? 0;
        final completed   = (stats['completed']      as num?)?.toInt()    ?? 0;
        final canceled    = (stats['canceled']       as num?)?.toInt()    ?? 0;
        final totalAmount = (stats['total_payments'] as num?)?.toDouble() ?? 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Статистика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
              children: [
                _buildStatCard(label: 'Всего', value: '$total', icon: Icons.fitness_center,
                    color: Theme.of(context).colorScheme.secondary),
                _buildStatCard(label: 'Проведено', value: '$completed', icon: Icons.check_circle_outline,
                    color: const Color(0xFF4CAF50)),
                _buildStatCard(label: 'Отменено', value: '$canceled', icon: Icons.cancel_outlined,
                    color: const Color(0xFFFF6B6B)),
                _buildStatCard(label: 'Оплат', value: '${totalAmount.toStringAsFixed(0)} ₽',
                    icon: Icons.payments_outlined, color: const Color(0xFF997A00)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({required String label, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Заметки о клиенте ──
  // Видны только тренеру: инфо-баннер под заголовком напоминает
  // об этом как в режиме просмотра, так и в режиме редактирования.
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Заметки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (!_editingNotes)
              TextButton.icon(
                onPressed: () => setState(() => _editingNotes = true),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Редактировать'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildNotesInfoBanner(),
        const SizedBox(height: 12),
        if (!_editingNotes)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.colorLightBlue, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Text(
              _client.notes?.isNotEmpty == true ? _client.notes! : 'Нет заметок',
              style: TextStyle(fontSize: 14,
                  color: _client.notes?.isNotEmpty == true ? null : Theme.of(context).colorScheme.outline),
            ),
          )
        else ...[
          TextField(
            controller: _notesController, minLines: 3, maxLines: 6, autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder(),
                hintText: 'Травмы, особенности, противопоказания...'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () { _notesController.text = _client.notes ?? ''; setState(() => _editingNotes = false); },
                child: const Text('Отмена'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _savingNotes ? null : () async { await _saveNotes(); if (!mounted) return; setState(() => _editingNotes = false); },
                child: _savingNotes
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNotesInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: AppColors.colorWhite.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Заметку видите только вы — клиенту она недоступна',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.colorWhite.withValues(alpha: 0.55),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionWeekCard(Map<String, dynamic> r) => _NutritionWeekCard(data: r);

  Widget _buildNutritionByMonth(List<Map<String, dynamic>> records) {
    final Map<String, List<Map<String, dynamic>>> byMonth = {};
    for (final r in records) {
      final weekStart = r['week_start'] as String? ?? '';
      if (weekStart.length < 7) continue;
      final monthKey = weekStart.substring(0, 7);
      byMonth.putIfAbsent(monthKey, () => []);
      byMonth[monthKey]!.add(r);
    }

    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    const monthNames = [
      '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];

    return Column(
      children: months.asMap().entries.map((entry) {
        final index     = entry.key;
        final monthKey  = entry.value;
        final weeks     = byMonth[monthKey]!;
        final parts     = monthKey.split('-');
        final year      = parts[0];
        final monthNum  = int.tryParse(parts[1]) ?? 0;
        final monthName = monthNum > 0 && monthNum <= 12 ? monthNames[monthNum] : monthKey;
        final title     = '$monthName $year';
        final isFirst   = index == 0;

        double sumCal = 0, sumProt = 0, sumFat = 0, sumCarb = 0;
        int counted = 0;
        for (final w in weeks) {
          if (w['avg_calories'] != null) {
            sumCal  += (w['avg_calories']  as num).toDouble();
            sumProt += (w['avg_protein']   as num? ?? 0).toDouble();
            sumFat  += (w['avg_fat']       as num? ?? 0).toDouble();
            sumCarb += (w['avg_carbohydrate'] as num? ?? 0).toDouble();
            counted++;
          }
        }
        final avgLabel = counted > 0
            ? '~${(sumCal / counted).toStringAsFixed(0)} ккал · ${weeks.length} нед.'
            : '${weeks.length} нед.';

        // Средние БЖУ за месяц — по тем же неделям, что и калории
        final String? macrosLabel = counted > 0
            ? 'Б ${(sumProt / counted).toStringAsFixed(0)} г · '
            'Ж ${(sumFat / counted).toStringAsFixed(0)} г · '
            'У ${(sumCarb / counted).toStringAsFixed(0)} г'
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.colorLightBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isFirst,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding: EdgeInsets.zero,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.colorWhite)),
                      ),
                      Text(avgLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                  if (macrosLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(macrosLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.colorWhite.withValues(alpha: 0.55))),
                  ],
                ],
              ),
              children: [
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                  child: Column(
                    children: weeks.map((r) => _buildNutritionWeekCard(r)).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBookingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text('История тренировок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
          onExpansionChanged: (expanded) {
            if (expanded && _bookingsFuture == null) {
              setState(() { _bookingsFuture = GetIt.instance<ClientRepository>().getClientBookings(_client.id); });
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                _filterChip('Все', 'all'), const SizedBox(width: 8),
                _filterChip('Проведённые', 'confirmed'), const SizedBox(width: 8),
                _filterChip('Отменённые', 'canceled'),
              ]),
            ),
            if (_bookingsFuture == null)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _bookingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text('Ошибка: ${snapshot.error}'));
                  var bookings = snapshot.data ?? [];
                  if (_bookingsFilter == 'confirmed') {
                    bookings = bookings.where((b) => b['confirmation_state'] == 'confirmed' && b['booking_state'] != 'canceled').toList();
                  } else if (_bookingsFilter == 'canceled') {
                    bookings = bookings.where((b) => b['booking_state'] == 'canceled').toList();
                  }
                  if (bookings.isEmpty) {
                    return Padding(padding: const EdgeInsets.all(16),
                        child: Text('Нет тренировок', style: TextStyle(color: Theme.of(context).colorScheme.outline)));
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      children: bookings.map((b) {
                        final date = DateTime.parse(b['scheduled_at']).toLocal();
                        final status = _bookingStatusLabel(b['booking_state'] ?? '', b['confirmation_state'] ?? '');
                        final statusColor = _bookingStatusColor(b['booking_state'] ?? '');
                        return _buildInfoCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          rows: [
                            _infoRow('Дата', DateFormat('dd.MM.yyyy HH:mm').format(date)),
                            _infoRow('Тип', _sessionTypeLabel(b['session_type'] ?? '')),
                            _infoRowColored('Статус', status, statusColor),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _bookingsFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _bookingsFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Text(label, style: TextStyle(fontSize: 12,
            color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.outline)),
      ),
    );
  }

  Widget _buildPaymentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text('История оплат', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
          onExpansionChanged: (expanded) {
            if (expanded && _paymentsFuture == null) {
              setState(() { _paymentsFuture = GetIt.instance<ClientRepository>().getClientPayments(_client.id); });
            }
          },
          children: [
            if (_paymentsFuture == null)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _paymentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text('Ошибка: ${snapshot.error}'));
                  final payments = snapshot.data ?? [];
                  if (payments.isEmpty) {
                    return Padding(padding: const EdgeInsets.all(16),
                        child: Text('Нет оплат', style: TextStyle(color: Theme.of(context).colorScheme.outline)));
                  }
                  return Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildPaymentsCards(payments));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsCards(List<Map<String, dynamic>> payments) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in payments) {
      final type = p['purchase_type'] as String? ?? 'single';
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(p);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped.containsKey('single')) ...[_paymentGroupTitle('Разовые тренировки'), _buildSinglePaymentCards(grouped['single']!), const SizedBox(height: 12)],
        if (grouped.containsKey('subscription')) ...[_paymentGroupTitle('Абонементы'), _buildSubscriptionPaymentCards(grouped['subscription']!), const SizedBox(height: 12)],
        if (grouped.containsKey('block')) ...[_paymentGroupTitle('Блоки тренировок'), _buildBlockPaymentCards(grouped['block']!), const SizedBox(height: 12)],
      ],
    );
  }

  Widget _paymentGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.surface)),
    );
  }

  Widget _buildSinglePaymentCards(List<Map<String, dynamic>> payments) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: payments.map((p) {
          final createdAt = DateTime.parse(p['created_at']).toLocal();
          final amount = p['amount']?.toString() ?? '—';
          final bookingId = p['booking_id'] as String?;
          return _buildInfoCard(
            margin: const EdgeInsets.only(bottom: 8),
            rows: [
              _infoRow('Дата оплаты', dateFormat.format(createdAt)),
              _infoRow('Сумма', '$amount ₽'),
              if (bookingId != null)
                _infoRowFuture('Дата тренировки', _bookingDateFutureCache.putIfAbsent(bookingId,
                        () => GetIt.instance<ClientRepository>().getBookingById(bookingId).then((b) =>
                    b?['scheduled_at'] != null ? dateFormat.format(DateTime.parse(b!['scheduled_at']).toLocal()) : '—')))
              else
                _infoRow('Дата тренировки', '—'),
              _infoRow('Статус', _paymentStatusLabel(p['status'] ?? '')),
              _infoRowReceipt(p['receipt_photo_url'] as String?),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubscriptionPaymentCards(List<Map<String, dynamic>> payments) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _subscriptionsFuture,
      builder: (context, subSnapshot) {
        if (subSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final subscriptions = subSnapshot.data ?? [];
        Map<String, dynamic>? findSub(Map<String, dynamic> payment) {
          if (subscriptions.isEmpty) return null;
          final paymentDate = DateTime.parse(payment['created_at']);
          final sorted = [...subscriptions];
          sorted.sort((a, b) => DateTime.parse(a['purchased_at']).difference(paymentDate).abs()
              .compareTo(DateTime.parse(b['purchased_at']).difference(paymentDate).abs()));
          return sorted.first;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: payments.map((p) {
              final createdAt = DateTime.parse(p['created_at']).toLocal();
              final sub = findSub(p);
              return _buildInfoCard(margin: const EdgeInsets.only(bottom: 8), rows: [
                _infoRow('Дата оплаты', dateFormat.format(createdAt)),
                _infoRow('Сумма', '${p['amount']?.toString() ?? '—'} ₽'),
                _infoRow('Начало', sub != null ? dateFormat.format(DateTime.parse(sub['valid_from'])) : '—'),
                _infoRow('Конец', sub != null ? dateFormat.format(DateTime.parse(sub['valid_until'])) : '—'),
                _infoRow('Статус аб.', sub != null ? _subscriptionStatusLabel(sub['status'] ?? '') : '—'),
                _infoRow('Статус оплаты', _paymentStatusLabel(p['status'] ?? '')),
                _infoRowReceipt(p['receipt_photo_url'] as String?),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBlockPaymentCards(List<Map<String, dynamic>> payments) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _blocksFuture,
      builder: (context, blockSnapshot) {
        if (blockSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final blocks = blockSnapshot.data ?? [];
        Map<String, dynamic>? findBlock(Map<String, dynamic> payment) {
          final meta = payment['metadata'] as Map<String, dynamic>?;
          final blockId = meta?['block_id'] as String?;
          if (blockId != null) {
            final found = blocks.where((b) => b['id'] == blockId).toList();
            if (found.isNotEmpty) return found.first;
          }
          final paymentDate = DateTime.parse(payment['created_at']);
          final sorted = [...blocks];
          sorted.sort((a, b) => DateTime.parse(a['purchased_at']).difference(paymentDate).abs()
              .compareTo(DateTime.parse(b['purchased_at']).difference(paymentDate).abs()));
          return sorted.isNotEmpty ? sorted.first : null;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: payments.map((p) {
              final createdAt = DateTime.parse(p['created_at']).toLocal();
              final block = findBlock(p);
              final total = block?['total_sessions'] as int? ?? 0;
              final used = block?['used_sessions'] as int? ?? 0;
              final reserved = block?['reserved_sessions'] as int? ?? 0;
              return _buildInfoCard(margin: const EdgeInsets.only(bottom: 8), rows: [
                _infoRow('Дата оплаты', dateFormat.format(createdAt)),
                _infoRow('Сумма', '${p['amount']?.toString() ?? '—'} ₽'),
                _infoRow('Начало', block != null ? dateFormat.format(DateTime.parse(block['purchased_at'])) : '—'),
                _infoRow('Конец', (block != null && block['exhausted_at'] != null) ? dateFormat.format(DateTime.parse(block['exhausted_at'])) : '—'),
                _infoRow('Статус блока', block != null ? _blockStatusLabel(block['status'] ?? '') : '—'),
                _infoRow('Всего', '$total'),
                _infoRow('Остаток', '${total - used - reserved}'),
                _infoRow('Статус оплаты', _paymentStatusLabel(p['status'] ?? '')),
                _infoRowReceipt(p['receipt_photo_url'] as String?),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required List<Widget> rows, EdgeInsets margin = EdgeInsets.zero}) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) => Column(children: [
          entry.value,
          if (entry.key < rows.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        ])).toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.colorGrey)),
          const SizedBox(width: 8),
          Flexible(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.colorWhite), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _infoRowColored(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.colorGrey)),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _infoRowFuture(String label, Future<String> future) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.colorGrey)),
          FutureBuilder<String>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5));
              }
              return Text(snapshot.data ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.colorWhite));
            },
          ),
        ],
      ),
    );
  }

  // ── Строка с чеком: показывает «Посмотреть», если чек загружен, иначе «Не загружен» ──
  Widget _infoRowReceipt(String? receiptPath) {
    final hasReceipt = receiptPath != null && receiptPath.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Чек', style: TextStyle(fontSize: 13, color: AppColors.colorGrey)),
          if (hasReceipt)
            InkWell(
              onTap: () => _showReceipt(receiptPath),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 15, color: Theme.of(context).colorScheme.surface),
                  const SizedBox(width: 4),
                  Text('Посмотреть',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.surface)),
                ],
              ),
            )
          else
            Text('Не загружен', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildActiveBlockInfo(Map<String, dynamic> block) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final total = block['total_sessions'] as int? ?? 0;
    final used = block['used_sessions'] as int? ?? 0;
    final reserved = block['reserved_sessions'] as int? ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Активный блок', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
        const SizedBox(height: 8),
        _buildInfoCard(rows: [
          _infoRow('Начало', dateFormat.format(DateTime.parse(block['purchased_at']))),
          _infoRow('Всего', '$total'),
          _infoRow('Использовано', '$used'),
          _infoRow('Забронировано', '$reserved'),
          _infoRow('Остаток', '${total - used - reserved}'),
        ]),
      ],
    );
  }

  Widget _buildActiveSubscriptionInfo(Map<String, dynamic> sub) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Активный абонемент', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
        const SizedBox(height: 8),
        _buildInfoCard(rows: [
          _infoRow('Начало', dateFormat.format(DateTime.parse(sub['valid_from']))),
          _infoRow('Конец', dateFormat.format(DateTime.parse(sub['valid_until']))),
          _infoRow('Статус', _subscriptionStatusLabel(sub['status'] ?? '')),
        ]),
      ],
    );
  }

  String _sessionTypeLabel(String type) {
    switch (type) {
      case 'single': return 'Разовая';
      case 'subscription': return 'Абонемент';
      case 'block': return 'Блок';
      default: return type;
    }
  }

  String _bookingStatusLabel(String bookingState, String confirmationState) {
    switch (bookingState) {
      case 'canceled': return 'Отменена';
      case 'rescheduled': return 'Перенесена';
      case 'completed': return 'Выполнена';
      case 'no_response': return 'Нет ответа';
      default:
        if (confirmationState == 'confirmed') return 'Подтверждена';
        if (confirmationState == 'declined') return 'Отменена клиентом';
        if (confirmationState == 'expired') return 'Истекло подтверждение';
        return 'Запланирована';
    }
  }

  Color _bookingStatusColor(String bookingState) {
    switch (bookingState) {
      case 'canceled': return const Color(0xFFFF6B6B);
      case 'rescheduled': return const Color(0xFF64B5F6);
      case 'completed': return const Color(0xFF9E9E9E);
      case 'no_response': return const Color(0xFFFFB74D);
      case 'scheduled': return const Color(0xFF4CAF50);
      default: return Colors.white;
    }
  }

  String _subscriptionStatusLabel(String status) {
    switch (status) {
      case 'active': return 'Активен';
      case 'expired': return 'Истёк';
      case 'canceled': return 'Отменён';
      default: return status;
    }
  }

  String _blockStatusLabel(String status) {
    switch (status) {
      case 'active': return 'Активен';
      case 'exhausted': return 'Исчерпан';
      case 'canceled': return 'Отменён';
      default: return status;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Ожидает';
      case 'receipt_uploaded': return 'Чек загружен';
      case 'completed': return 'Оплачено';
      case 'failed': return 'Ошибка';
      case 'refunded': return 'Возврат';
      default: return status;
    }
  }
}

// =============================================================================
// _FatsecretToggle
// =============================================================================

class _FatsecretToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _FatsecretToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? AppColors.colorWhite.withValues(alpha: 0.15)
              : AppColors.colorWhite.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.restaurant_rounded : Icons.no_meals_outlined,
            size: 18,
            color: enabled
                ? AppColors.colorWhite
                : AppColors.colorWhite.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Интеграция FatSecret',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.colorWhite
                        : AppColors.colorWhite.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  enabled
                      ? 'Включена — КБЖУ приходит еженедельно'
                      : 'Отключена — данные питания не собираются',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.colorWhite.withValues(alpha: enabled ? 0.6 : 0.3),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: AppColors.colorDarkRed,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _NutritionWeekCard
// =============================================================================

class _NutritionWeekCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _NutritionWeekCard({required this.data});
  @override
  State<_NutritionWeekCard> createState() => _NutritionWeekCardState();
}

class _NutritionWeekCardState extends State<_NutritionWeekCard> {
  bool _expanded = false;

  static String _fmt(dynamic v) => v != null ? (v as num).toStringAsFixed(0) : '—';

  static String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return '${days[dt.weekday - 1]}, ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  List<Map<String, dynamic>> _parseDays() {
    final raw = widget.data['raw_data'];
    if (raw == null) return [];
    try {
      if (raw is List) return raw.cast<Map<String, dynamic>>();
      if (raw is String) return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.data;
    final dateFormat = DateFormat('dd.MM.yyyy');
    final weekStart = r['week_start'] != null ? dateFormat.format(DateTime.parse(r['week_start'] as String)) : '—';
    final weekEnd = r['week_end'] != null ? dateFormat.format(DateTime.parse(r['week_end'] as String)) : '—';
    final daysTracked = r['days_tracked'] as int? ?? 0;
    final hasDays = r['raw_data'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.colorLightBlue, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: hasDays ? () => setState(() => _expanded = !_expanded) : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(8),
                  bottom: _expanded ? Radius.zero : const Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$weekStart — $weekEnd',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.colorWhite)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: daysTracked >= 5 ? const Color(0xFF4CAF50).withValues(alpha: 0.15) : const Color(0xFFFF9800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: daysTracked >= 5 ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : const Color(0xFFFF9800).withValues(alpha: 0.4)),
                      ),
                      child: Text('$daysTracked / 7 дней', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                          color: daysTracked >= 5 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800))),
                    ),
                    if (hasDays) ...[
                      const SizedBox(width: 6),
                      AnimatedRotation(turns: _expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.colorWhite)),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(child: _NutritionStatCell(label: 'Калории', value: _fmt(r['avg_calories']), unit: 'ккал', color: const Color(0xFFFF6B6B), icon: Icons.local_fire_department)),
              const SizedBox(width: 8),
              Expanded(child: _NutritionStatCell(label: 'Белки', value: _fmt(r['avg_protein']), unit: 'г', color: const Color(0xFF64B5F6), icon: Icons.egg_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _NutritionStatCell(label: 'Жиры', value: _fmt(r['avg_fat']), unit: 'г', color: const Color(0xFFFFB74D), icon: Icons.opacity)),
              const SizedBox(width: 8),
              Expanded(child: _NutritionStatCell(label: 'Углеводы', value: _fmt(r['avg_carbohydrate']), unit: 'г', color: const Color(0xFFCE93D8), icon: Icons.grain)),
            ]),
          ),
          if (_expanded && hasDays) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: _buildDailyBreakdown(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown(BuildContext context) {
    final days = _parseDays();
    if (days.isEmpty) return const Text('Нет данных по дням', style: TextStyle(color: AppColors.colorGrey, fontSize: 12));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Детализация по дням', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.colorGrey)),
        const SizedBox(height: 8),
        _dayRow(context, date: 'День', calories: 'Ккал', protein: 'Б', fat: 'Ж', carbs: 'У', isHeader: true),
        const SizedBox(height: 4),
        ...days.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _dayRow(context,
              date: _fmtDate(d['date'] as String? ?? ''),
              calories: _fmt(d['calories']), protein: _fmt(d['protein']),
              fat: _fmt(d['fat']), carbs: _fmt(d['carbohydrate']), isHeader: false),
        )),
      ],
    );
  }

  Widget _dayRow(BuildContext context, {required String date, required String calories,
    required String protein, required String fat, required String carbs, required bool isHeader}) {
    Widget cell(String v, Color color) => Expanded(child: Text(v, textAlign: TextAlign.right,
        style: isHeader ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.colorGrey)
            : TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: isHeader ? Colors.transparent : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Text(date,
            style: isHeader ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.colorGrey)
                : const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.colorWhite))),
        cell(calories, const Color(0xFFFF6B6B)),
        cell(protein, const Color(0xFF64B5F6)),
        cell(fat, const Color(0xFFFFB74D)),
        cell(carbs, const Color(0xFFCE93D8)),
      ]),
    );
  }
}

class _NutritionStatCell extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final IconData icon;

  const _NutritionStatCell({required this.label, required this.value, required this.unit, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(unit, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.colorGrey), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}