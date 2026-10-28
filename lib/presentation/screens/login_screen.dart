import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';
import 'package:formeo/ui/widgets/app_text_field.dart';
import 'package:formeo/core/constants/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocusNode = FocusNode();

  bool _obscure = true;
  bool _isLoading = false;

  final Map<String, String> _errorMessages = {
    'Invalid login credentials': 'Неверный email или пароль',
    'Email not confirmed': 'Email не подтверждён — проверьте почту',
    'User not found': 'Пользователь не найден',
    'Too many requests': 'Слишком много попыток — попробуйте позже',
    'Network request failed': 'Ошибка сети — проверьте подключение',
    'invalid_credentials': 'Неверный email или пароль',
  };

  String _localizeError(String message) {
    for (final entry in _errorMessages.entries) {
      if (message.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      if (!mounted) return;
      setState(() => _emailController.text = savedEmail);
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
  }

  int _passwordScore(String password) {
    var score = 0;
    if (password.length >= 8) score += 2;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 1;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score += 1;
    return score;
  }

  Color _passwordColor(int score) {
    if (score <= 1) return const Color(0xFFFF6B6B);
    if (score == 2) return const Color(0xFF997A00);
    return const Color(0xFF4CAF50);
  }

  String _passwordLabel(int score) {
    if (score <= 1) return 'Слабый';
    if (score == 2) return 'Средний';
    return 'Сильный';
  }

  void _onEmailSignIn() {
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      _saveEmail(_emailController.text.trim());
      context.read<AuthBloc>().add(SignIn(
        _emailController.text.trim(),
        _passwordController.text,
      ));
    }
  }

  void _onMagicLink() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите email для отправки ссылки')),
      );
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный email')),
      );
      return;
    }
    context.read<AuthBloc>().add(SendMagicLink(email));
  }

  void _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введите email для восстановления пароля')),
      );
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный email')),
      );
      return;
    }
    try {
      await GetIt.instance<SupabaseDataSource>().resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Письмо для сброса пароля отправлено на вашу почту'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: ${_localizeError(e.toString())}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordScore = _passwordScore(_passwordController.text);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthAuthenticated) {
          context.go('/main');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localizeError(state.message))),
          );
        } else if (state is MagicLinkSent) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ссылка отправлена'),
              content: const Text(
                'Проверьте вашу почту — мы отправили ссылку для входа. '
                    'Перейдите по ней чтобы войти в приложение.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
//        appBar: AppBar(title: const Text('Вход')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Заголовок
                  Text(
                    'Добро пожаловать',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Войдите в свой аккаунт',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.colorGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Email
                  AppTextField(
                    label: 'Email',
                    hint: 'example@mail.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Пожалуйста, введите email';
                      }
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Введите корректный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Пароль
                  AppTextField(
                    label: 'Пароль',
                    hint: 'Введите пароль',
                    controller: _passwordController,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() {}),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.colorGrey,
                      ),
                    ),
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

                  // Индикатор сложности пароля
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: passwordScore.clamp(0, 5) / 5,
                              minHeight: 6,
                              backgroundColor:
                              AppColors.colorGrey.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _passwordColor(passwordScore),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _passwordLabel(passwordScore),
                          style: TextStyle(
                            fontSize: 12,
                            color: _passwordColor(passwordScore),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Забыли пароль
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _onForgotPassword,
                      child: const Text('Забыли пароль?'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Кнопка входа по паролю
                  ElevatedButton(
                    onPressed: _isLoading ? null : _onEmailSignIn,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.colorWhite,
                      ),
                    )
                        : const Text('Войти'),
                  ),
                  const SizedBox(height: 12),

                  // Разделитель
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.colorGrey.withValues(alpha: 0.5),
                        ),
                      ),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'или',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.colorGrey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.colorGrey.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Кнопка Magic Link
                  OutlinedButton(
                    onPressed: _isLoading ? null : _onMagicLink,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: AppColors.colorDarkRed),
                      foregroundColor: AppColors.colorWhite,
                    ),
                    child: const Text('Войти по ссылке на email'),
                  ),

                  const SizedBox(height: 16),

                  // Регистрация
                  TextButton(
                    onPressed:
                    _isLoading ? null : () => context.go('/register'),
                    child: const Text('Нет аккаунта? Зарегистрироваться'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}