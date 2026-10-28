import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class CheckAuth implements UseCase<User?, void> {
  final AuthRepository repository;

  CheckAuth(this.repository);

  @override
  Future<User?> execute(void params) async {
    try {
      return await repository.checkAuthStatus();
    } catch (e) {
      throw AuthException('Ошибка проверки статуса аутентификации: $e');
    }
  }
}
