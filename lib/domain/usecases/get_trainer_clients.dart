import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/repositories/client_repository.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class GetTrainerClients implements UseCase<List<Client>, String> {
  final ClientRepository repository;

  GetTrainerClients(this.repository);

  @override
  Future<List<Client>> execute(String userId) async {
    try {
      return await repository.fetchClients(userId);
    } catch (e) {
      throw DataException('Ошибка при получении списка клиентов: $e');
    }
  }
}

