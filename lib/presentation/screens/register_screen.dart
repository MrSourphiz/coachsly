import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:coachsly/presentation/blocs/auth_bloc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});


  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // keep role for compatibility with existing SignUp event signature
  String _role = 'trainer';
  bool _showAdvanced = false; // hide role by default (progressive profiling)
  String _timezone = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignUp() {
    if (_formKey.currentState?.validate() ?? false) {
    // Existing project used SignUp(email, password, role) — keep that call
      context.read<AuthBloc>().add(SignUp(
        _emailController.text.trim(),
        _passwordController.text,
        _role,
        _timezone,
      ));

    // After sign-up you likely expect an email/phone verification screen —
    // let the bloc handle navigation (it already did in provided files).
    }
  }

  void _onSocialTap(String provider) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('TODO: register with $provider')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Создать аккаунт', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text('Минимум данных — максимум результата. Можно добавить данные позже.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),

              // Social buttons
              ElevatedButton.icon(
                onPressed: () => _onSocialTap('google'),
                icon: Image.asset('assets/icons/google.png', height: 20),
                label: const Text('Продолжить с Google'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _onSocialTap('apple'),
                icon: Icon(kIsWeb ? Icons.login : Icons.fingerprint),
                label: const Text('Продолжить с Apple'),
              ),
              const SizedBox(height: 12),
              Center(child: Text('или', style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(height: 12),

              Form(
                key: _formKey,
                child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Пожалуйста, введите email';
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value.trim())) return 'Введите корректный email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Пароль'),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите пароль';
                          if (value.length < 6) return 'Пароль должен быть не менее 6 символов';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Progressive profile: advanced fields hidden by default
                      GestureDetector(
                        onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Дополнительно (опционально)'),
                            Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                          ],
                        ),
                      ),
                      if (_showAdvanced) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _role,
                          items: ['trainer', 'client']
                              .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                              .toList(),
                          onChanged: (v) => setState(() => _role = v ?? _role),
                          decoration: const InputDecoration(labelText: 'Роль'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _onSignUp, child: const Text('Создать аккаунт')),


                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Уже есть аккаунт? Войти'),
                        ),
                      ],
                    ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }
}