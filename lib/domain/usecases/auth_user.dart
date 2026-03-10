import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/user.dart';
import 'package:coachsly/domain/repositories/auth_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class AuthUserParams {
  final String email;
  final String password;

  AuthUserParams(this.email, this.password);
}

class AuthenticateUser implements UseCase<User, AuthUserParams> {
  final AuthRepository repository;

  AuthenticateUser(this.repository);

  @override
  Future<User> execute(AuthUserParams params) async {
    try {
      return await repository.login(params.email, params.password);
    } catch (e) {
      throw AuthException('Ошибка аутентификации: $e');
    }
  }
}