import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Екран входу / реєстрації — ввід номера телефону та пароля.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+380');
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLogin = true; // true = вхід, false = реєстрація

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    final password = _passwordController.text.trim();

    if (phone.length < 10 || password.isEmpty) {
      _showError('Заповніть усі поля');
      return;
    }

    if (_isLogin) {
      final ok = await auth.login(phone, password);
      if (!ok && mounted) _showError(auth.error ?? 'Помилка входу');
    } else {
      final firstName = _firstNameController.text.trim();
      if (firstName.isEmpty) {
        _showError("Введіть ім'я");
        return;
      }
      final lastName = _lastNameController.text.trim();
      await auth.register(
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName.isNotEmpty ? lastName : null,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: CLIXTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: CLIXTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // ── Заголовок форми ──
                  Text(
                    _isLogin ? 'Вхід до акаунту' : 'Реєстрація',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: CLIXTheme.spaceSm),
                  Text(
                    _isLogin
                        ? 'Введіть номер телефону для входу'
                        : 'Створіть акаунт для замовлення таксі',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: CLIXTheme.spaceXl),

                  // ── Ім'я (тільки для реєстрації) ──
                  if (!_isLogin) ...[
                    _fieldLabel("Ім'я"),
                    const SizedBox(height: CLIXTheme.spaceSm),
                    TextField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Олексій',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: CLIXTheme.spaceMd),
                    _fieldLabel("Прізвище (необов'язково)"),
                    const SizedBox(height: CLIXTheme.spaceSm),
                    TextField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Коваленко',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: CLIXTheme.spaceMd),
                  ],

                  // ── Поле телефону ──
                  _fieldLabel('Номер телефону'),
                  const SizedBox(height: CLIXTheme.spaceSm),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[+0-9 ]')),
                    ],
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇺🇦', style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      hintText: '+380 97 123 4567',
                    ),
                  ),
                  const SizedBox(height: CLIXTheme.spaceMd),

                  // ── Поле пароля ──
                  _fieldLabel('Пароль'),
                  const SizedBox(height: CLIXTheme.spaceSm),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Мінімум 6 символів',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: CLIXTheme.textHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: CLIXTheme.spaceXl),

                  // ── Кнопка ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleSubmit,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(_isLogin ? 'Увійти' : 'Зареєструватися'),
                    ),
                  ),

                  const SizedBox(height: CLIXTheme.spaceLg),

                  // ── Перемикач вхід/реєстрація ──
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isLogin = !_isLogin;
                        _firstNameController.clear();
                        _lastNameController.clear();
                      }),
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin
                              ? 'Ще немає акаунту? '
                              : 'Вже є акаунт? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Зареєструватися' : 'Увійти',
                              style: const TextStyle(
                                color: CLIXTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CLIXTheme.spaceXl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CLIXTheme.textPrimary,
      ),
    );
  }
}
