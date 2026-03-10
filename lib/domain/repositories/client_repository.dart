import 'package:coachsly/domain/entities/client.dart';

abstract class ClientRepository {
  /// Получает список клиентов для указанного тренера.
  /// [trainerId] - идентификатор тренера.
  /// Возвращает список сущностей [Client].
  Future<List<Client>> fetchClients(String trainerId);

  /// Добавляет нового клиента для указанного тренера.
  /// [trainerId] - идентификатор тренера.
  /// [name] - имя клиента.
  /// [phoneNumber] - номер телефона клиента.
  /// [notes] - заметка тренера (необязательное поле).
  Future<void> addNewClient(String trainerId, String name, String phoneNumber, {String? notes});

  /// Генерирует ссылку-приглашение для клиента с использованиеи ИД тренера.
  /// [trainerId] - идентификатор тренера.
  /// Возвращает ссылку в виде строки.
  Future<String> createInvitation(String trainerId);

  /// Удаляет ссылку-приглашение из таблицы.
  /// [token] - токен приглашения.
  Future<void> deleteInvitation(String token);

  /// Регистрирует клиента по указанному токену.
  /// [token] - токен.
  /// [name] - имя клиента.
  /// [phoneNumber] - номер телефона клиента.
  Future<void> registerClientWithToken(String token, String name, String phoneNumber);

  /// Обновляет статус клиента по указанному clientId.
  /// [clientId] - идентификатор клиента.
  /// [status] - текущий статус клиента.
  Future<void> updateClientStatus(String clientId, String status);

  /// Удаляет клиента по указанному clientId.
  /// [clientId] - идентификатор клиента.
  Future<void> deleteClient(String clientId);
}