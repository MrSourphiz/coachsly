import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/domain/entities/user.dart';
import 'package:formeo/domain/repositories/auth_repository.dart';
import 'package:formeo/domain/repositories/exercises_repository.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/presentation/providers/user_provider.dart';
import 'package:formeo/core/service/push_notification_service.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/data/repositories/exrcises_repository_impl.dart';

// ───── События ─────
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

class SendMagicLink extends AuthEvent {
  final String email;
  SendMagicLink(this.email);
}

// ───── Состояния ─────
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

class MagicLinkSent extends AuthState {}

// Регистрация прошла успешно, но email ещё не подтверждён.
// Сессии нет — пользователь должен проверить почту.
class AuthEmailConfirmationRequired extends AuthState {
  final String email;
  AuthEmailConfirmationRequired(this.email);
}

// ───── Блок ─────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserProvider userProvider = GetIt.I<UserProvider>();

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>((event, emit) async {
      try {
        final user = await authRepository.checkAuthStatus();
        debugPrint('CheckAuthStatus result: $user');
        if (user != null) {
          userProvider.setUser(user);
          GetIt.instance<PushNotificationService>().initialize(user.id);
          emit(AuthAuthenticated(user));
        } else {
          // null = сессии нет, это точная информация → разлогиниваем
          userProvider.clearUser();
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        debugPrint('Ошибка в CheckAuthStatus: $e');
        // Если уже есть активное состояние AuthAuthenticated — не разлогиниваем.
        // Ошибка могла быть сетевой, а не связанной с авторизацией.
        if (state is AuthAuthenticated) {
          debugPrint('CheckAuthStatus: уже авторизован, игнорируем ошибку');
          return;
        }
        userProvider.clearUser();
        emit(AuthUnauthenticated());
      }
    });

    on<SignUp>((event, emit) async {
      try {
        emit(AuthLoading());
        debugPrint('Регистрация пользователя: ${event.email}, роль: ${event.role}');
        await authRepository.register(
          event.email,
          event.password,
          event.role,
          event.timezone,
        );
        debugPrint('Пользователь зарегистрирован: ${event.email}');
        // Не создаём сессию — ждём подтверждения email.
        // userProvider и PushNotifications инициализируются после входа.
        emit(AuthEmailConfirmationRequired(event.email));
      } catch (e) {
        debugPrint('Ошибка в SignUp: $e');
        final msg = e is AppException ? e.message : e.toString();
        emit(AuthError(msg));
      }
    });

    on<SignIn>((event, emit) async {
      try {
        emit(AuthLoading());
        final user = await authRepository.login(
          event.email,
          event.password,
        );
        debugPrint('Пользователь вошёл: ${user.email}');
        userProvider.setUser(user);

        GetIt.instance<PushNotificationService>().initialize(user.id);
        emit(AuthAuthenticated(user));
      } catch (e) {
        debugPrint('Ошибка в SignIn: $e');
        final msg = e is AppException ? e.message : e.toString();
        emit(AuthError(msg));
      }
    });

    on<SignOut>((event, emit) async {
      try {
        await authRepository.logout();
        userProvider.clearUser();
        // Сбрасываем кэш упражнений — следующий пользователь получит свежие данные
        final exercises = GetIt.instance<ExercisesRepository>();
        if (exercises is ExerciseRepositoryImpl) {
          exercises.invalidate();
        }
        emit(AuthUnauthenticated());
      } catch (e) {
        emit(AuthError('Ошибка выхода: $e'));
      }
    });

    on<SendMagicLink>((event, emit) async {
      try {
        emit(AuthLoading());
        await GetIt.instance<SupabaseDataSource>()
            .signInWithMagicLink(event.email);
        emit(MagicLinkSent());
      } catch (e) {
        debugPrint('Ошибка в SendMagicLink: $e');
        emit(AuthError('Ошибка отправки ссылки: $e'));
      }
    });
  }
}
