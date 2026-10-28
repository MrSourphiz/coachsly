import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:formeo/core/constants/messenger.dart';

/// Вариант оформления карточки приглашения.
enum InvitationCardStyle {
  /// Тёмный фон онбординга (белый текст, QR в белой плашке).
  onDark,

  /// Внутри диалога — цвета берутся из темы.
  themed,
}

/// QR-код + ссылка + «Поделиться» с переключателем Telegram / MAX.
///
/// Токен приглашения один и тот же для обоих мессенджеров — бот в каждом
/// из них сам привяжет клиента к тренеру. Переключатель меняет только ссылку.
class InvitationQrCard extends StatefulWidget {
  final String token;
  final InvitationCardStyle style;
  final double qrSize;
  final ValueChanged<Messenger>? onMessengerChanged;

  const InvitationQrCard({
    super.key,
    required this.token,
    this.style = InvitationCardStyle.themed,
    this.qrSize = 180,
    this.onMessengerChanged,
  });

  /// Последний выбранный мессенджер — запоминаем на время сессии,
  /// чтобы тренер не переключал его каждый раз.
  static Messenger lastSelected = Messenger.telegram;

  @override
  State<InvitationQrCard> createState() => _InvitationQrCardState();
}

class _InvitationQrCardState extends State<InvitationQrCard> {
  late Messenger _messenger = InvitationQrCard.lastSelected;

  bool get _onDark => widget.style == InvitationCardStyle.onDark;

  String get _url => _messenger.inviteUrl(widget.token);

  void _select(Messenger m) {
    if (m == _messenger) return;
    HapticFeedback.selectionClick();
    setState(() => _messenger = m);
    InvitationQrCard.lastSelected = m;
    widget.onMessengerChanged?.call(m);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = _onDark ? AppColors.colorWhite : scheme.onSurface;
    final mutedColor = textColor.withValues(alpha: 0.65);
    final url = _url;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MessengerSwitch(
          value: _messenger,
          onDark: _onDark,
          onChanged: _select,
        ),
        const SizedBox(height: 18),

        // ── QR ──
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: Container(
              key: ValueKey(_messenger),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.colorWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _messenger.brandColor.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: widget.qrSize,
                backgroundColor: AppColors.colorWhite,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: _messenger.brandColor,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.colorBlue,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Клиент наведёт камеру — откроется бот в ${_messenger.label}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: mutedColor, height: 1.35),
        ),
        const SizedBox(height: 14),

        // ── Ссылка + копировать ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: _onDark
                ? AppColors.colorWhite.withValues(alpha: 0.08)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _onDark
                  ? AppColors.colorWhite.withValues(alpha: 0.15)
                  : scheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  url,
                  maxLines: 2,
                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                ),
              ),
              IconButton(
                tooltip: 'Скопировать',
                icon: Icon(Icons.copy_rounded, size: 20, color: textColor),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ссылка для ${_messenger.label} скопирована')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Поделиться ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Share.share(url),
            icon: Icon(Icons.share, color: textColor),
            label: Text(
              'Отправить клиенту',
              style: TextStyle(color: textColor),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: textColor.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Переключатель Telegram / MAX
// ─────────────────────────────────────────────────────────────

class _MessengerSwitch extends StatelessWidget {
  final Messenger value;
  final bool onDark;
  final ValueChanged<Messenger> onChanged;

  const _MessengerSwitch({
    required this.value,
    required this.onDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trackColor = onDark
        ? AppColors.colorWhite.withValues(alpha: 0.08)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final idleText = onDark
        ? AppColors.colorWhite.withValues(alpha: 0.7)
        : scheme.onSurface.withValues(alpha: 0.7);

    return Semantics(
      label: 'Мессенджер для приглашения',
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onDark
                ? AppColors.colorWhite.withValues(alpha: 0.12)
                : scheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: Messenger.values.map((m) {
            final selected = m == value;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: m.label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: selected ? m.brandColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: selected
                          ? [
                        BoxShadow(
                          color: m.brandColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          m.icon,
                          size: 18,
                          color: selected ? Colors.white : idleText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : idleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
