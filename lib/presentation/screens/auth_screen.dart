import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:coachsly/presentation/blocs/auth_bloc.dart';

class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.I<AuthBloc>()..add(CheckAuthStatusEvent()),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return Scaffold(
                body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.secondary, // Бордовый
                      ),
                    ),
                ),
            );
          } else if (state is AuthAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/main');
            });
            return Container(); // Временный контейнер, так как переход происходит сразу
          } else if (state is AuthUnauthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/login');
            });
            return Container();
          } else {
            return Scaffold(
                body: Center(
                    child: Text(
                        'Initializing...',
                         style: Theme.of(context).textTheme.bodyLarge,
                    ),
                ),
            );
          }
        },
      ),
    );
  }
}