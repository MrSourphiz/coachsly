import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class CheckAuthStatus implements UseCase<bool, void> {
  final AuthRepository repository;

  CheckAuthStatus(this.repository);

  @override
  Future<bool> execute(void params) async {
    try {
      final user = await repository.checkAuthStatus();
      return user != null;
    } catch (e) {
      throw AuthException('Ошибка проверки статуса аутентификации: $e');
    }
  }
}
