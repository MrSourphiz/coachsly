import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:formeo/presentation/blocs/auth_bloc.dart';
import 'package:formeo/ui/widgets/app_text_field.dart';
import 'package:formeo/core/constants/colors.dart';

// ── Ссылки на юридические документы — актуализировать под реальный домен ──
const _termsUrl = 'https://myformeo.ru/terms.html';
const _privacyUrl = 'https://myformeo.ru/privacy-policy.html';

// Ключ, под которым временно кэшируется факт согласия при регистрации —
// сама запись в БД (terms_accepted_at/privacy_accepted_at) происходит позже,
// в checkAuthStatus() (auth_repository_impl.dart), потому что на момент
// регистрации public.users может ещё не существовать (если требуется
// подтверждение email — сессии ещё нет, писать в БД нельзя из-за RLS).
const kPendingConsentKey = 'pending_registration_consent_at';
const _storage = FlutterSecureStorage();

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _role = 'trainer';
  String _timezone = '';

  // Согласие с Пользовательским соглашением и Политикой конфиденциальности —
  // без него кнопка "Зарегистрироваться" неактивна.
  bool _consentGiven = false;

  // Русификация ошибок
  final Map<String, String> _errorMessages = {
    'User already registered': 'Пользователь с таким email уже существует',
    'Password should be at least 6 characters':
    'Пароль должен быть не менее 6 символов',
    'Unable to validate email address':
    'Некорректный email адрес',
    'Network request failed': 'Ошибка сети — проверьте подключение',
    'Too many requests': 'Слишком много попыток — попробуйте позже',
  };

  String _localizeError(String message) {
    for (final entry in _errorMessages.entries) {
      if (message.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return message;
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _onSignUp() async {
    if (_isLoading) return;
    if (!_consentGiven) return; // подстраховка — кнопка и так неактивна
    if (_formKey.currentState?.validate() ?? false) {
      // Кэшируем факт и время согласия локально ДО отправки SignUp —
      // в БД это попадёт при первом checkAuthStatus() (см. комментарий
      // у kPendingConsentKey выше).
      await _storage.write(
        key: kPendingConsentKey,
        value: DateTime.now().toIso8601String(),
      );

      if (mounted) {
        context.read<AuthBloc>().add(SignUp(
          _emailController.text.trim(),
          _passwordController.text,
          _role,
          _timezone,
        ));
      }
    }
  }

  Widget _buildConsentCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _consentGiven,
            onChanged: (v) => setState(() => _consentGiven = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _consentGiven = !_consentGiven),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.colorGrey,
                ),
                children: [
                  const TextSpan(text: 'Регистрируясь, я принимаю условия '),
                  TextSpan(
                    text: 'Пользовательского соглашения',
                    style: const TextStyle(decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(Uri.parse(_termsUrl),
                          mode: LaunchMode.externalApplication),
                  ),
                  const TextSpan(text: ' и даю согласие на обработку персональных данных согласно '),
                  TextSpan(
                    text: 'Политике конфиденциальности',
                    style: const TextStyle(decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(Uri.parse(_privacyUrl),
                          mode: LaunchMode.externalApplication),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
        } else if (state is AuthEmailConfirmationRequired) {
          context.go('/email-confirmation', extra: state.email);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localizeError(state.message))),
          );
        }
      },
      child: Scaffold(
//        appBar: AppBar(title: const Text('Регистрация')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Заголовок
                  Text(
                    'Создать аккаунт',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заполните данные для регистрации',
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
                    hint: 'Минимум 6 символов',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
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
                  const SizedBox(height: 16),

                  // Подтверждение пароля
                  AppTextField(
                    label: 'Подтвердите пароль',
                    hint: 'Повторите пароль',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    onChanged: (_) => setState(() {}),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.colorGrey,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Подтвердите пароль';
                      }
                      if (value != _passwordController.text) {
                        return 'Пароли не совпадают';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Чекбокс согласия — обязателен
                  _buildConsentCheckbox(),
                  const SizedBox(height: 20),

                  // Кнопка регистрации
                  ElevatedButton(
                    onPressed: (_isLoading || !_consentGiven) ? null : _onSignUp,
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
                        : const Text('Зарегистрироваться'),
                  ),
                  const SizedBox(height: 16),

                  // Переход на вход
                  TextButton(
                    onPressed: _isLoading ? null : () => context.go('/login'),
                    child: const Text('Уже есть аккаунт? Войти'),
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
