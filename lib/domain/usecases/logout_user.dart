import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class LogoutUser implements UseCase<void, void> {
  final AuthRepository repository;

  LogoutUser(this.repository);

  @override
  Future<void> execute(void params) async {
    try {
      await repository.logout();
    } catch (e) {
      throw AuthException('Ошибка выхода: $e');
    }
  }
}
