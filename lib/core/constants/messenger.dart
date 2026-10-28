import 'package:flutter/material.dart';

/// Мессенджер, через который клиент общается с ботом.
///
/// В БД оба типа клиентов лежат в `telegram_clients`:
///   telegram_user_id > 0 — Telegram,
///   telegram_user_id < 0 — MAX (user_id со знаком минус).
enum Messenger { telegram, max }

/// Настройки ботов.
class MessengerConfig {
  MessengerConfig._();

  /// Username Telegram-бота (без @).
  static const String telegramBotUsername = 'formeo_crm_bot';

  /// Никнейм бота в MAX — тот, что в ссылке https://max.ru/<ник>.
  static const String maxBotName = 'se14712551_bot';
}

extension MessengerX on Messenger {
  String get label => switch (this) {
    Messenger.telegram => 'Telegram',
    Messenger.max => 'MAX',
  };

  /// Фирменный цвет — для переключателя и бейджей.
  Color get brandColor => switch (this) {
    Messenger.telegram => const Color(0xFF229ED9),
    Messenger.max => const Color(0xFF7B3FF2),
  };

  IconData get icon => switch (this) {
    Messenger.telegram => Icons.telegram,
    Messenger.max => Icons.chat_bubble_rounded,
  };

  /// Ссылка-приглашение в бота с токеном.
  /// Telegram: https://t.me/<bot>?start=<token>
  /// MAX:      https://max.ru/<bot>?start=<token>  (payload до 128 символов)
  String inviteUrl(String token) => switch (this) {
    Messenger.telegram =>
    'https://t.me/${MessengerConfig.telegramBotUsername}?start=$token',
    Messenger.max => 'https://max.ru/${MessengerConfig.maxBotName}?start=$token',
  };

  /// Ссылка на профиль клиента по username (если он есть).
  String? profileUrl(String? username) {
    if (username == null || username.isEmpty) return null;
    return switch (this) {
      Messenger.telegram => 'https://t.me/$username',
      Messenger.max => 'https://max.ru/$username',
    };
  }

  String get dbValue => name;
}

Messenger messengerFromTelegramUserId(int telegramUserId) =>
    telegramUserId < 0 ? Messenger.max : Messenger.telegram;

Messenger messengerFromDb(String? value, {int? telegramUserId}) {
  if (value == 'max') return Messenger.max;
  if (value == 'telegram') return Messenger.telegram;
  if (telegramUserId != null) return messengerFromTelegramUserId(telegramUserId);
  return Messenger.telegram;
}
