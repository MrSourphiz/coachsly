import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class LoginUserParams {
  final String email;
  final String password;

  LoginUserParams(this.email, this.password);
}

class LoginUser implements UseCase<User, LoginUserParams> {
  final AuthRepository repository;

  LoginUser(this.repository);

  @override
  Future<User> execute(LoginUserParams params) async {
    try {
      return await repository.login(params.email, params.password);
    } catch (e) {
      throw AuthException('Ошибка входа: $e');
    }
  }
}
