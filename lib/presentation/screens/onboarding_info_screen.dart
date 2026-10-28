import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/core/service/onboarding_progress_service.dart';

// ─────────────────────────────────────────────────────────────
//  OnboardingInfoScreen — Блок 1 (4 информационных слайда)
//
//  Слайд 0 — Уведомления о тренировках
//  Слайд 1 — Блоки и абонементы
//  Слайд 2 — Оплаты
//  Слайд 3 — Удержание клиентов
//
//  После последнего слайда → /onboarding (настройка профиля)
// ─────────────────────────────────────────────────────────────

class OnboardingInfoScreen extends StatefulWidget {
  const OnboardingInfoScreen({super.key});

  @override
  State<OnboardingInfoScreen> createState() => _OnboardingInfoScreenState();
}

class _OnboardingInfoScreenState extends State<OnboardingInfoScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;
  // Шаги 0–3 в глобальном прогресс-баре
  static const int _globalStepOffset = 0;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorBlue,
      body: SafeArea(
        child: Column(
          children: [
            // ── Глобальный прогресс-бар ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: OnboardingProgressBar(),
            ),

            // ── Контент ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  GetIt.instance<OnboardingProgressService>()
                      .setStep(_globalStepOffset + i);
                },
                children: [
                  _buildSlide0Notifications(),
                  _buildSlide1Blocks(),
                  _buildSlide2Payments(),
                  _buildSlide3Retention(),
                  _buildSlide4Fatsecret(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Общие виджеты ───

  Widget _proBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.colorDarkRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.colorDarkRed.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.colorDarkRed,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSlideShell({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required List<Widget> content,
    bool proBadge = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконка + бейдж Pro
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              if (proBadge) ...[
                const SizedBox(width: 10),
                _proBadge(),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Заголовок
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.colorWhite,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Подзаголовок
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.colorWhite.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Контент слайда
          ...content,

          const SizedBox(height: 32),

          // Кнопка
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorDarkRed,
                foregroundColor: AppColors.colorWhite,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorWhite.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor ?? AppColors.colorWhite.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        color: AppColors.colorWhite.withValues(alpha: 0.35),
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // ─── Слайд 0: Уведомления ───

  Widget _buildSlide0Notifications() {
    return _buildSlideShell(
      icon: Icons.notifications_active_outlined,
      iconColor: const Color(0xFF60A5FA),
      iconBg: const Color(0xFF60A5FA).withValues(alpha: 0.15),
      title: 'Хватит быть будильником для клиентов',
      subtitle: 'Ты вносишь тренировку в календарь, а все остальное берёт на себя бот Formeo. Твоя работа - тренировать, а не писать "завтра в 10?" по 50 раз в день.',
      buttonLabel: 'Далее',
      content: [
        _buildTimelineItem(
          timeLabel: 'Сейчас',
          dotColor: const Color(0xFF60A5FA),
          showLine: true,
          title: 'Тренировка добавлена',
          description: 'Клиент получает сообщение в Telegram с датой и временем',
          tags: null,
        ),
        _buildTimelineItem(
          timeLabel: 'За 24ч',
          dotColor: const Color(0xFF60A5FA),
          showLine: true,
          title: 'Бот спрашивает придёт или нет',
          description: 'Клиент отвечает кнопкой прямо в чате',
          tags: ['✓ Приду', '✗ Отменяю'],
        ),
        _buildTimelineItem(
          timeLabel: 'За 8ч',
          dotColor: const Color(0xFFF59E0B),
          showLine: true,
          title: 'Бот напомнит снова если клиент не ответил',
          description: null,
          accentColor: const Color(0xFFF59E0B),
        ),
        _buildTimelineItem(
          timeLabel: '!',
          dotColor: const Color(0xFFF87171),
          showLine: false,
          title: 'В случае форс-мажора Formeo предупредит тебя',
          description: null,
          accentColor: const Color(0xFFF87171),
          titleColor: const Color(0xFFF87171),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String timeLabel,
    required Color dotColor,
    required bool showLine,
    required String title,
    String? description,
    List<String>? tags,
    Color? accentColor,
    Color? titleColor,
  }) {
    final cardBg = accentColor != null
        ? accentColor.withValues(alpha: 0.1)
        : AppColors.colorWhite.withValues(alpha: 0.07);
    final cardBorder = accentColor != null
        ? accentColor.withValues(alpha: 0.25)
        : AppColors.colorWhite.withValues(alpha: 0.1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Время
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              timeLabel,
              style: TextStyle(
                fontSize: 12,
                color: titleColor ?? AppColors.colorWhite.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        // Точка + линия
        SizedBox(
          width: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (showLine)
                Container(
                  width: 1.5,
                  height: 52,
                  color: AppColors.colorWhite.withValues(alpha: 0.15),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Карточка
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppColors.colorWhite,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (tags != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: tags.map((tag) {
                        final isPositive = tag.startsWith('✓');
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFF34D399).withValues(alpha: 0.15)
                                : const Color(0xFFF87171).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: isPositive
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Слайд 1: Блоки и абонементы ───

  Widget _buildSlide1Blocks() {
    return _buildSlideShell(
      icon: Icons.inventory_2_outlined,
      iconColor: const Color(0xFFA78BFA),
      iconBg: const Color(0xFFA78BFA).withValues(alpha: 0.15),
      title: 'Считать блоки в уме? Забудь.',
      subtitle: 'Formeo сам списывает тренировки, показывает остаток и, когда блок заканчивается, предлагает клиенту продление, без твоего участия.',
      buttonLabel: 'Далее',
      content: [
        _sectionLabel('Активные блоки клиентов'),
        _buildBlockCard(
          name: 'Алексей Петров',
          type: 'Блок · 10 тренировок',
          badgeText: '8 из 10',
          badgeColor: const Color(0xFF34D399),
          progress: 0.8,
          progressColor: const Color(0xFF34D399),
          metaLeft: 'использовано 8',
          metaRight: 'осталось 2',
        ),
        _buildBlockCard(
          name: 'Марина Соколова',
          type: 'Абонемент · 30 дней',
          badgeText: '5 дней',
          badgeColor: const Color(0xFFF59E0B),
          progress: 0.83,
          progressColor: const Color(0xFFF59E0B),
          metaLeft: '25 из 30 дней',
          metaRight: 'истекает 14 июня',
        ),
        const SizedBox(height: 4),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Formeo списывает тренировку с блока после её проведения',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _sectionLabel('У клиента заканчивается блок или абонемент?'),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_outlined,
                  color: Color(0xFFA78BFA), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Бот сам напишет клиенту',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Предложит взять новый блок, абонемент или альтернативу — разовые тренировки. Ты не тратишь время на лишнюю писанину.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.send_outlined,
                  color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Клиент выбрал продолжение - бот сразу присылает реквизиты для оплаты',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockCard({
    required String name,
    required String type,
    required String badgeText,
    required Color badgeColor,
    required double progress,
    required Color progressColor,
    required String metaLeft,
    required String metaRight,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colorWhite.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.colorWhite.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.colorWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.colorWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
              AppColors.colorWhite.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metaLeft,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.colorWhite.withValues(alpha: 0.4))),
              Text(metaRight,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.colorWhite.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Слайд 2: Оплаты ───

  Widget _buildSlide2Payments() {
    return _buildSlideShell(
      icon: Icons.payments_outlined,
      iconColor: const Color(0xFF34D399),
      iconBg: const Color(0xFF34D399).withValues(alpha: 0.15),
      title: 'Не хочешь терять деньги - перестань напоминать об оплате вручную.',
      subtitle: 'Клиент подтвердил тренировку - бот сразу кидает реквизиты. Не заплатил - ты видишь статус. Блок закончился - бот сам предложит новый и пришлёт счёт.',
      buttonLabel: 'Далее',
      content: [
        _sectionLabel('Статус по каждой тренировке'),
        _buildPaymentRow('Алексей Петров', 'Разовая · 3 июня', true),
        _buildPaymentRow('Марина Соколова', 'Разовая · 3 июня', false),
        _buildPaymentRow('Дмитрий Ларин', 'Блок 10 занятий', true),
        const SizedBox(height: 8),
        _sectionLabel('Когда бот напоминает об оплате'),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline,
                  color: Color(0xFF60A5FA), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Разовая тренировка',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Как только клиент подтвердил бот присылает реквизиты',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Блок или абонемент',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'По окончании бот сам предложит клиенту продолжить',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ты прямо в приложении сможешь посмотреть все чеки',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String name, String subtitle, bool isPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colorWhite.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.colorWhite.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.colorWhite.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFF34D399).withValues(alpha: 0.15)
                  : const Color(0xFFF87171).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPaid ? 'Оплачено' : 'Не оплачено',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPaid
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF87171),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Слайд 3: Удержание ───

  Widget _buildSlide3Retention() {
    return _buildSlideShell(
      icon: Icons.monitor_heart_outlined,
      iconColor: const Color(0xFFF87171),
      iconBg: const Color(0xFFF87171).withValues(alpha: 0.15),
      proBadge: true,
      title: 'Клиенты не предупреждают, что уходят, а просто молча пропадают.',
      subtitle:
      'Formeo даёт тебе сигналы: красный – срочно написать, жёлтый – проверить, зелёный – всё ок. Раз в месяц клиент получает статистику – это мотивация для него и доказательство твоей работы для тебя.',
      buttonLabel: 'Далее',
      content: [
        // Статистика
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE84B3A).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE84B3A).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Text(
                '50%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF87171),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'клиентов уходят в первые полгода. Чаще всего это можно было предотвратить',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.colorWhite.withValues(alpha: 0.55),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        _sectionLabel('Сигналы в профиле каждого клиента'),
        _buildSignalRow(
          color: const Color(0xFFEF4444),
          bg: const Color(0xFFEF4444).withValues(alpha: 0.1),
          border: const Color(0xFFEF4444).withValues(alpha: 0.2),
          title: 'Красный — надо написать прямо сейчас',
          description:
          'Пропустил две тренировки подряд или написал что чувствует себя плохо',
        ),
        _buildSignalRow(
          color: const Color(0xFFF59E0B),
          bg: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          border: const Color(0xFFF59E0B).withValues(alpha: 0.2),
          title: 'Жёлтый — стоит уточнить как дела',
          description: 'Ходит заметно реже чем обычно',
        ),
        _buildSignalRow(
          color: const Color(0xFF22C55E),
          bg: const Color(0xFF22C55E).withValues(alpha: 0.08),
          border: const Color(0xFF22C55E).withValues(alpha: 0.15),
          title: 'Зелёный — всё хорошо',
        ),
        const SizedBox(height: 8),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFFA78BFA), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Каждые две недели бот спрашивает клиента как дела (ты увидишь ответы в профиле клиента)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.show_chart_outlined,
                  color: Color(0xFF60A5FA), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Раз в месяц клиент получает свою статистику',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Сколько тренировок было, как менялось самочувствие. Для клиента это мотивация продолжать. Для тебя это наглядное подтверждение результата, который ты создаёшь.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignalRow({
    required Color color,
    required Color bg,
    required Color border,
    required String title,
    String? description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorWhite,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.colorWhite.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Слайд 5: FatSecret (Pro) ───

  Widget _buildSlide4Fatsecret() {
    return _buildSlideShell(
      icon: Icons.restaurant_menu_outlined,
      iconColor: const Color(0xFFFBBF24),
      iconBg: const Color(0xFFFBBF24).withValues(alpha: 0.15),
      proBadge: true,
      title: 'Хватит спрашивать "что ты ел?". Просто открой профиль.',
      subtitle:
      'Клиент привязал FatSecret – ты видишь его КБЖУ за день и за неделю. Без скриншотов, без "я ем мало, но не худею". Только факты.',
      buttonLabel: 'Далее',
      content: [
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link_outlined,
                  color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Клиент привязывает свой аккаунт FatSecret',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Это занимает пару минут и дальше всё работает само',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bar_chart_outlined,
                  color: Color(0xFF60A5FA), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'КБЖУ клиента — у тебя в приложении',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.colorWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Видишь раскладку по дням, со средним значением за неделю прямо в профиле клиента, без лишних скриншотов и пересылок',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.colorWhite.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
