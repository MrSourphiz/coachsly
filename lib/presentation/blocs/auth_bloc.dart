import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:coachsly/domain/entities/user.dart';
import 'package:coachsly/domain/repositories/auth_repository.dart';
import 'package:coachsly/presentation/providers/user_provider.dart';

abstract class AuthEvent {}
class CheckAuthStatusEvent extends AuthEvent {}
class SignUp extends AuthEvent {
  final String email;
  final String password;
  final String role;
  final String timezone;
  SignUp(this.email, this.password, this.role, this.timezone);
}
class SignIn extends AuthEvent {
  final String email;
  final String password;
  SignIn(this.email, this.password);
}
class SignOut extends AuthEvent {}

abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserProvider userProvider = GetIt.I<UserProvider>();

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>((event, emit) async {
      try {
        final user = await authRepository.checkAuthStatus();
        print('CheckAuthStatus result: $user');
        if (user != null) {
          userProvider.setUser(user);
          emit(AuthAuthenticated(user));
        } else {
          userProvider.clearUser();
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        print('Ошибка в CheckAuthStatus: $e');
        userProvider.clearUser();
        emit(AuthUnauthenticated());
      }
    });

    on<SignUp>((event, emit) async {
      try {
        emit(AuthLoading());
        print('Регистрация пользователя: ${event.email}, роль: ${event.role}');
        final user = await authRepository.register(
          event.email,
          event.password,
          event.role,
          event.timezone,
        );
        print('Пользователь зарегистрирован: ${user.email}');
        userProvider.setUser(user);
        emit(AuthAuthenticated(user));
      } catch (e) {
        print('Ошибка в SignUp: $e');
        if (e.toString().contains('user_already_exists')) {
          emit(AuthError('Пользователь с таким email уже зарегистрирован'));
        } else {
          emit(AuthError('Ошибка регистрации: $e'));
        }
      }
    });

    on<SignIn>((event, emit) async {
      try {
        emit(AuthLoading());
        final user = await authRepository.login(
          event.email,
          event.password,
        );
        print('Пользователь вошёл: ${user.email}');
        userProvider.setUser(user);
        emit(AuthAuthenticated(user));
      } catch (e) {
        print('Ошибка в SignIn: $e');
        emit(AuthError('Ошибка входа: $e'));
      }
    });

    on<SignOut>((event, emit) async {
      try {
        await authRepository.logout();
        userProvider.clearUser();
        emit(AuthUnauthenticated());
      } catch (e) {
        emit(AuthError('Ошибка выхода: $e'));
      }
    });
  }
}