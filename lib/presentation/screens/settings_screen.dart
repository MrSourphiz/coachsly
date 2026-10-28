import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/ui/widgets/app_text_field.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/core/service/push_notification_service.dart';
import 'package:formeo/core/constants/billing_config.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';

/// Слово, которое нужно ввести для подтверждения удаления аккаунта.
const _deleteConfirmWord = 'УДАЛИТЬ';

// ── Ссылки на юридические документы — актуализировать при смене домена ──
const _ofertaUrl = 'https://myformeo.ru/oferta.html';
const _privacyUrl = 'https://myformeo.ru/privacy-policy.html';

class TrainerSettingsScreen extends StatefulWidget {
  @override
  _TrainerSettingsScreenState createState() => _TrainerSettingsScreenState();
}

class _TrainerSettingsScreenState extends State<TrainerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Реквизиты
  final _phoneController = TextEditingController();
  final _bankController = TextEditingController();

  // Стоимость
  final _singlePriceController = TextEditingController();
  final _blockPriceController = TextEditingController();
  final _subscriptionPriceController = TextEditingController();
  final _blockSessionsController = TextEditingController();
  final _subscriptionDaysController = TextEditingController();

  // Профиль
  final _locationController = TextEditingController();
  String _selectedTimezone = 'Europe/Moscow';

  // Тех поддержка
  final _supportController = TextEditingController();
  bool _sendingSupport = false;
  bool _supportSent = false;

  // Fatsecret
  bool _fatsecretNeeded = false;
  bool _savingFatsecret = false;

  // Push-уведомления
  AuthorizationStatus _pushStatus = AuthorizationStatus.notDetermined;
  bool _savingPush = false;

  // Подписка / автопродление
  bool _savingAutoRenew = false;

  bool _loading = true;
  bool _savingRequisites = false;
  bool _savingPrices = false;
  bool _savingProfile = false;

  // Удаление аккаунта
  bool _deletingAccount = false;

  final List<String> _timezones = [
    'Europe/Kaliningrad',
    'Europe/Moscow',
    'Europe/Samara',
    'Asia/Yekaterinburg',
    'Asia/Omsk',
    'Asia/Krasnoyarsk',
    'Asia/Irkutsk',
    'Asia/Yakutsk',
    'Asia/Vladivostok',
    'Asia/Magadan',
    'Asia/Kamchatka',
  ];

  final Map<String, String> _timezoneLabels = {
    'Europe/Kaliningrad': 'Калининград (UTC+2)',
    'Europe/Moscow': 'Москва (UTC+3)',
    'Europe/Samara': 'Самара (UTC+4)',
    'Asia/Yekaterinburg': 'Екатеринбург (UTC+5)',
    'Asia/Omsk': 'Омск (UTC+6)',
    'Asia/Krasnoyarsk': 'Красноярск (UTC+7)',
    'Asia/Irkutsk': 'Иркутск (UTC+8)',
    'Asia/Yakutsk': 'Якутск (UTC+9)',
    'Asia/Vladivostok': 'Владивосток (UTC+10)',
    'Asia/Magadan': 'Магадан (UTC+11)',
    'Asia/Kamchatka': 'Камчатка (UTC+12)',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bankController.dispose();
    _singlePriceController.dispose();
    _blockPriceController.dispose();
    _subscriptionPriceController.dispose();
    _locationController.dispose();
    _blockSessionsController.dispose();
    _subscriptionDaysController.dispose();
    _supportController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // ✅ Сначала заполняем всё что уже есть локально — экран открывается мгновенно
    final user = GetIt.instance<UserProvider>().user!;
    _locationController.text = user.location ?? '';
    _selectedTimezone = _timezones.contains(user.timezone)
        ? user.timezone
        : 'Europe/Moscow';
    setState(() => _loading = false); // снимаем блокировку сразу

    // Статус пуш-уведомлений — читаем сразу, это быстрый вызов
    final pushStatus =
    await GetIt.instance<PushNotificationService>().getPermissionStatus();
    if (mounted) setState(() => _pushStatus = pushStatus);

    // Затем догружаем данные из БД в фоне
    try {
      final dataSource = GetIt.instance<SupabaseDataSource>();
      final results = await Future.wait([
        dataSource.getTrainerPaymentDetails(user.id),
        dataSource.getFatsecretNeeded(user.id),
      ]);

      final details = results[0] as Map<String, dynamic>?;
      final fatsecretNeeded = results[1] as bool;

      if (!mounted) return;

      setState(() {
        if (details != null) {
          _phoneController.text = details['phone_number'] ?? '';
          _bankController.text = details['preferred_bank'] ?? '';
          _singlePriceController.text =
              details['single_price']?.toString() ?? '';
          _blockPriceController.text =
              details['block_price']?.toString() ?? '';
          _subscriptionPriceController.text =
              details['subscription_price']?.toString() ?? '';
          _blockSessionsController.text =
              details['block_sessions']?.toString() ?? '';
          _subscriptionDaysController.text =
              details['subscription_days']?.toString() ?? '';
        }
        _fatsecretNeeded = fatsecretNeeded;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  Future<void> _saveRequisites() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите номер телефона')),
      );
      return;
    }
    setState(() => _savingRequisites = true);
    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>().saveTrainerPaymentDetails(
        trainerId: user.id,
        phoneNumber: _phoneController.text,
        preferredBank: _bankController.text.isNotEmpty
            ? _bankController.text
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Реквизиты сохранены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      setState(() => _savingRequisites = false);
    }
  }

  Future<void> _savePrices() async {
    setState(() => _savingPrices = true);
    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>().saveTrainerPaymentDetails(
        trainerId: user.id,
        phoneNumber: _phoneController.text,
        preferredBank: _bankController.text.isNotEmpty
            ? _bankController.text
            : null,
        singlePrice: _singlePriceController.text.isNotEmpty
            ? double.tryParse(_singlePriceController.text)
            : null,
        blockPrice: _blockPriceController.text.isNotEmpty
            ? double.tryParse(_blockPriceController.text)
            : null,
        subscriptionPrice: _subscriptionPriceController.text.isNotEmpty
            ? double.tryParse(_subscriptionPriceController.text)
            : null,
        blockSessions: _blockSessionsController.text.isNotEmpty
            ? int.tryParse(_blockSessionsController.text)
            : null,
        subscriptionDays: _subscriptionDaysController.text.isNotEmpty
            ? int.tryParse(_subscriptionDaysController.text)
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Стоимость сохранена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      setState(() => _savingPrices = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>().updateTrainerProfile(
        trainerId: user.id,
        timezone: _selectedTimezone,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
      );

      final updatedUser = user.copyWith(
        timezone: _selectedTimezone,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
      );
      GetIt.instance<UserProvider>().setUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _toggleFatsecret(bool value) async {
    setState(() => _savingFatsecret = true);
    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>()
          .setFatsecretNeeded(user.id, value);
      setState(() => _fatsecretNeeded = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'Интеграция с Fatsecret включена'
                : 'Интеграция с Fatsecret отключена'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFatsecret = false);
    }
  }

  Future<void> _togglePush(bool value) async {
    final user = GetIt.instance<UserProvider>().user!;
    final service = GetIt.instance<PushNotificationService>();

    // Разрешение отклонено на уровне ОС — сами мы это не включим,
    // ведём пользователя в системные настройки приложения.
    if (value && _pushStatus == AuthorizationStatus.denied) {
      await ph.openAppSettings();
      // После возврата из настроек перечитываем актуальный статус
      final refreshed = await service.getPermissionStatus();
      if (mounted) setState(() => _pushStatus = refreshed);
      return;
    }

    setState(() => _savingPush = true);
    try {
      if (value) {
        final status = await service.enableNotifications(user.id);
        if (mounted) setState(() => _pushStatus = status);
        if (mounted && status == AuthorizationStatus.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Уведомления отключены в настройках устройства. '
                    'Включите их в системных настройках приложения.',
              ),
            ),
          );
        }
      } else {
        await service.disableNotifications(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Уведомления отключены')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPush = false);
    }
  }

  /// Включает/выключает автопродление подписки Robokassa.
  /// Сама подписка (доступ до конца оплаченного периода) не затрагивается —
  /// меняется только то, будет ли robokassa-recurring-charge списывать
  /// следующий платёж.
  Future<void> _toggleAutoRenew(bool value) async {
    final userProvider = GetIt.instance<UserProvider>();
    final user = userProvider.user!;

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Отменить автопродление?'),
          content: Text(
            'Доступ сохранится до '
                '${user.nextBillingAt != null ? _formatDate(user.nextBillingAt!) : "конца оплаченного периода"}'
                ', но новое списание произведено не будет.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Отключить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _savingAutoRenew = true);
    try {
      await GetIt.instance<SupabaseClient>()
          .from('users')
          .update({'auto_renew': value})
          .eq('id', user.id);
      userProvider.setUser(user.copyWith(autoRenew: value));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'Автопродление включено'
                : 'Автопродление отключено'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAutoRenew = false);
    }
  }

  /// Удаление аккаунта: двойное подтверждение (диалог + ввод слова),
  /// затем Edge Function `delete-account` и локальный выход через AuthBloc.
  /// Роутер сам уведёт на /auth, когда AuthBloc перейдёт в Unauthenticated.
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await GetIt.instance<SupabaseDataSource>().deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аккаунт удалён')),
      );
      GetIt.instance<AuthBloc>().add(SignOut());
    } catch (e) {
      if (mounted) {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _sendSupportRequest() async {
    if (_supportController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст обращения')),
      );
      return;
    }

    setState(() => _sendingSupport = true);

    try {
      final user = GetIt.instance<UserProvider>().user!;
      await GetIt.instance<SupabaseDataSource>().sendSupportRequest(
        trainerId: user.id,
        message: _supportController.text.trim(),
      );
      _supportController.clear();
      setState(() => _supportSent = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сообщение отправлено в тех поддержку. Мы вас уведомим о результатах.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _supportSent = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingSupport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        _buildContent(),
        // Блокируем экран на время удаления, чтобы не было повторных нажатий
        // и переходов, пока сервер чистит данные.
        if (_deletingAccount)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollapsibleSection(
                title: 'Локация',
                child: _buildProfileSection(),
                onSave: _saveProfile,
                saving: _savingProfile,
                saveLabel: 'Сохранить локацию',
              ),
              const SizedBox(height: 8),
              _buildCollapsibleSection(
                title: 'Платёжные реквизиты',
                child: _buildRequisitesSection(),
                onSave: _saveRequisites,
                saving: _savingRequisites,
                saveLabel: 'Сохранить реквизиты',
                hint: '1. Сохраните реквизиты\n'
                    '2. После тренировки бот отправит клиенту реквизиты\n'
                    '3. Клиент оплатит и отправит чек боту\n'
                    '4. Вы получите уведомление и чек в приложении',
              ),
              const SizedBox(height: 8),
              _buildCollapsibleSection(
                title: 'Стоимость тренировок',
                child: _buildPricesSection(),
                onSave: _savePrices,
                saving: _savingPrices,
                saveLabel: 'Сохранить стоимость',
              ),
              const SizedBox(height: 8),

              // ───── Push-уведомления ─────
              _buildPushSection(),
              const SizedBox(height: 8),

              // ───── Подписка (автопродление) ─────
              _buildSubscriptionSection(),
              const SizedBox(height: 8),

              /*
              // ───── Fatsecret ─────
              _buildFatsecretSection(),
              const SizedBox(height: 8),
             */
              // ───── Документы ─────
              _buildDocumentsSection(),
              const SizedBox(height: 8),

              // ───── Тех поддержка ─────
              _buildSupportSection(),
              const SizedBox(height: 8),

              // ───── Удаление аккаунта ─────
              _buildDeleteAccountSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPushSection() {
    final isOn = _pushStatus == AuthorizationStatus.authorized ||
        _pushStatus == AuthorizationStatus.provisional;
    final isDeniedByOs = _pushStatus == AuthorizationStatus.denied;

    String statusLabel;
    if (isOn) {
      statusLabel = 'Включено';
    } else if (isDeniedByOs) {
      statusLabel = 'Отключено в настройках устройства';
    } else {
      statusLabel = 'Выключено';
    }

    return ExpansionTile(
      title: const Text(
        'Push-уведомления',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Уведомления о новых бронированиях, оплатах и активности клиентов.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.outline,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Получать push-уведомления',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _savingPush
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Switch(
                value: isOn,
                activeColor: Theme.of(context).colorScheme.secondary,
                onChanged: _togglePush,
              ),
            ],
          ),
        ),
        if (isDeniedByOs) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Уведомления заблокированы в системных настройках. '
                        'Нажмите переключатель, чтобы открыть настройки приложения '
                        'и включить их вручную.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Раздел "Подписка" — виден только если есть активная платная подписка
  /// (для тех, кто на бесплатном триале, отменять пока нечего).
  Widget _buildSubscriptionSection() {
    final user = GetIt.instance<UserProvider>().user!;
    if (user.subscriptionStatus != 'active') return const SizedBox.shrink();

    return ExpansionTile(
      title: const Text(
        'Подписка',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          user.autoRenew
              ? 'Подписка продлевается автоматически каждый расчётный период.'
              : 'Автопродление отключено — доступ сохранится до конца уже оплаченного периода.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.outline,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.autoRenew
                          ? 'Автопродление включено'
                          : 'Автопродление отключено',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.nextBillingAt != null
                          ? '${user.autoRenew ? "Следующее списание" : "Доступ до"}: ${_formatDate(user.nextBillingAt!)}'
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _savingAutoRenew
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Switch(
                value: user.autoRenew,
                activeColor: Theme.of(context).colorScheme.secondary,
                // iOS: отключить можно, включить обратно — нет
                // (это согласие на новые списания = покупка вне App Store).
                onChanged: (!BillingConfig.inAppPaymentsAllowed && !user.autoRenew)
                    ? null
                    : _toggleAutoRenew,
              ),
            ],
          ),
        ),
        // Ссылка на кабинет — только там, где разрешена оплата (Android/web).
        if (BillingConfig.inAppPaymentsAllowed) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(BillingConfig.cabinetUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Сменить тариф в личном кабинете'),
          ),
        ],
      ],
    );
  }
  // ignore: unused_element
  Widget _buildFatsecretSection() {
    return ExpansionTile(
      title: const Text(
        'Интеграция с Fatsecret',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // ── Описание ──
        Text(
          'После включения интеграции, чат-бот Formeo запросит у ваших клиентов разрешение на доступ к их дневникам питания Fatsecret. Вы будете в автоматическом режиме получать актуальную информацию по КБЖУ за прошедшую неделю каждый понедельник.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.outline,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // ── Переключатель ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Запрашивать доступ к Fatsecret',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fatsecretNeeded ? 'Включено' : 'Выключено',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _savingFatsecret
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Switch(
                value: _fatsecretNeeded,
                activeColor: Theme.of(context).colorScheme.secondary,
                onChanged: _toggleFatsecret,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Логотип Fatsecret ──
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_dining, size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                'Powered by FatSecret',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Раздел "Документы" — оферта и политика конфиденциальности,
  /// открываются во внешнем браузере.
  Widget _buildDocumentsSection() {
    return ExpansionTile(
      title: const Text(
        'Документы',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildDocumentLink(
          icon: Icons.description_outlined,
          title: 'Публичная оферта',
          url: _ofertaUrl,
        ),
        _buildDocumentLink(
          icon: Icons.privacy_tip_outlined,
          title: 'Политика конфиденциальности',
          url: _privacyUrl,
        ),
      ],
    );
  }

  Widget _buildDocumentLink({
    required IconData icon,
    required String title,
    required String url,
  }) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Theme.of(context).colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return ExpansionTile(
      title: const Text(
        'Обратиться в тех поддержку',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        if (_supportSent) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF256D47).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF256D47).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF4ADE80),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Сообщение отправлено в тех поддержку. Мы вас уведомим о результатах.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.surface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _supportController,
          minLines: 4,
          maxLines: 8,
          enabled: !_supportSent,
          decoration: InputDecoration(
            hintText: 'Опишите проблему или задайте вопрос...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.colorWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.colorGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.colorGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.colorDarkRed,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: const TextStyle(
            color: AppColors.colorBlue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_sendingSupport || _supportSent)
                ? null
                : _sendSupportRequest,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _sendingSupport
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Отправить'),
          ),
        ),
      ],
    );
  }

  /// Раздел "Удаление аккаунта" — свёрнут по умолчанию, чтобы не нажать случайно.
  /// Обязателен для публикации в App Store / Google Play.
  Widget _buildDeleteAccountSection() {
    final errorColor = Theme.of(context).colorScheme.error;

    return ExpansionTile(
      title: Text(
        'Удаление аккаунта',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: errorColor,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Аккаунт и все связанные данные будут удалены безвозвратно: '
              'клиенты, расписание, программы тренировок, платежи, '
              'промокоды и настройки. Telegram-бот перестанет работать '
              'с вашими клиентами.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.outline,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deletingAccount ? null : _deleteAccount,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: errorColor,
              side: BorderSide(color: errorColor),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Удалить аккаунт'),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required Widget child,
    required VoidCallback onSave,
    required bool saving,
    required String saveLabel,
    String? hint,
  }) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (hint != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: saving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(saveLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Часовой пояс',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.colorWhite,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedTimezone,
          dropdownColor: AppColors.colorWhite,
          style: const TextStyle(
            color: AppColors.colorBlue,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.colorWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.colorGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.colorGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.colorDarkRed,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _timezones
              .map((tz) => DropdownMenuItem(
            value: tz,
            child: Text(
              _timezoneLabels[tz] ?? tz,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.colorBlue,
              ),
            ),
          ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedTimezone = val);
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Локация',
          hint: 'Москва, зал FitnessPro, ул. Ленина 1',
          controller: _locationController,
        ),
      ],
    );
  }

  Widget _buildRequisitesSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        AppTextField(
          label: 'Номер телефона для СБП',
          hint: '+7 (999) 123-45-67',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Предпочитаемый банк',
          hint: 'Сбербанк, Тинькофф...',
          controller: _bankController,
        ),
      ],
    );
  }

  Widget _buildPricesSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        AppTextField(
          label: 'Разовая тренировка (₽)',
          hint: '1500',
          controller: _singlePriceController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Блок тренировок (₽)',
          hint: '8500',
          controller: _blockPriceController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        AppTextField(
          label: 'Количество тренировок в блоке',
          hint: '10',
          controller: _blockSessionsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Абонемент в месяц (₽)',
          hint: '12500',
          controller: _subscriptionPriceController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        AppTextField(
          label: 'Срок действия абонемента (дней)',
          hint: '30',
          controller: _subscriptionDaysController,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
/// Диалог подтверждения удаления аккаунта.
/// Кнопка «Удалить» активна только после ввода слова [_deleteConfirmWord].
/// Отдельный StatefulWidget, чтобы контроллер жил и освобождался вместе с диалогом.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim().toUpperCase() == _deleteConfirmWord;
      if (ok != _canDelete) setState(() => _canDelete = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = GetIt.instance<UserProvider>().user;
    final hasPaidSubscription = user?.subscriptionStatus == 'active';
    final errorColor = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: const Text('Удалить аккаунт?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Это действие нельзя отменить. Все ваши данные, клиенты '
                  'и история тренировок будут удалены без возможности восстановления.',
            ),
            if (hasPaidSubscription) ...[
              const SizedBox(height: 12),
              const Text(
                'Подписка будет отменена, автопродление отключено. '
                    'Остаток оплаченного периода не возвращается.',
              ),
            ],
            const SizedBox(height: 16),
            const Text('Для подтверждения введите $_deleteConfirmWord:'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: _deleteConfirmWord,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: errorColor),
          child: const Text('Удалить'),
        ),
      ],
    );
  }
}