import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int _passwordScore(String password) {
    var score = 0;
    if (password.length >= 8) score += 2;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 1;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score += 1;
    return score; // 0..5
  }

  String _passwordLabel(int score) {
    if (score <= 1) return 'Слабый';
    if (score == 2) return 'Средний';
    return 'Сильный';
  }

  void _onEmailSignIn() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(SignIn(
        _emailController.text,
        _passwordController.text,
      ));
    }
  }

  void _onSocialTap(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('TODO: sign in with $provider')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordScore = _passwordScore(_passwordController.text);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
            const Center(child: CircularProgressIndicator()),
          );
        } else {
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        }

        if (state is AuthAuthenticated) {
          context.go('/main');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Вход')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text('Быстрый вход',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                    'Войдите в 1–2 тапа через Google, Apple или телефон',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),

                // Social buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _onSocialTap('google'),
                        icon: Icon(kIsWeb ? Icons.login : Icons.fingerprint),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _onSocialTap('apple'),
                        icon: Icon(kIsWeb ? Icons.login : Icons.fingerprint),
                        label: const Text('Apple'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                    child: Text('или',
                        style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 12),

                // Email / password form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                        const InputDecoration(labelText: 'Email'),
                        style: Theme.of(context).textTheme.labelMedium,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Пожалуйста, введите email';
                          }
                          final emailRegex =
                          RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Введите корректный email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        style: Theme.of(context).textTheme.labelMedium,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                        ),
                        obscureText: _obscure,
                        onChanged: (s) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите пароль';
                          }
                          if (value.length < 6) {
                            return 'Пароль должен быть не менее 6 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_passwordController.text.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value:
                                (passwordScore.clamp(0, 5) / 5),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_passwordLabel(passwordScore)),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text('TODO: Восстановление пароля')),
                            );
                          },
                          child: const Text('Забыли пароль?'),
                        ),
                      ),

                      ElevatedButton(
                        onPressed: _onEmailSignIn,
                        child: const Text('Войти'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Нет аккаунта? Зарегистрироваться'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
