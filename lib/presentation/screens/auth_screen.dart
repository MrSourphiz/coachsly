import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';

class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // BlocProvider.value — не закрывает bloc при удалении виджета.
    // AuthBloc — lazySingleton в GetIt, его жизненным циклом управляет GetIt,
    // а не BlocProvider. Использование BlocProvider(create:...) здесь
    // приводило к close() при навигации, после чего singleton становился мёртвым.
    return BlocProvider.value(
      value: GetIt.I<AuthBloc>(),
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
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            );
          } else if (state is AuthAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/main');
            });
            return Container();
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
