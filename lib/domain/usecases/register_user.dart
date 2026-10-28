import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/usecases/use_case.dart';

class RegisterUserParams {
  final String email;
  final String password;
  final String role;
  final String timezone;

  RegisterUserParams(this.email, this.password, this.role, this.timezone);
}

class RegisterUser implements UseCase<User, RegisterUserParams> {
  final AuthRepository repository;

  RegisterUser(this.repository);

  @override
  Future<User> execute(RegisterUserParams params) async {
    try {
      return await repository.register(params.email, params.password, params.role, params.timezone);
    } catch (e) {
      throw AuthException('Ошибка регистрации: $e');
    }
  }
}
