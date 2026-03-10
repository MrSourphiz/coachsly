import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/repositories/auth_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

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