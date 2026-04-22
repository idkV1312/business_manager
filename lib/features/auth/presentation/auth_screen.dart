import 'package:business_manager/core/di/app_scope.dart';
import 'package:business_manager/shared/models/auth_session.dart';
import 'package:business_manager/shared/network/api_client.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;
  UserRole _role = UserRole.user;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final app = AppScope.of(context);
      if (_isLogin) {
        await app.login(_email.text.trim(), _password.text.trim());
      } else {
        await app.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text.trim(),
          _role,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is PendingApprovalException) {
        setState(() => _isLogin = true);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLogin ? 'Вход' : 'Регистрация',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Имя'),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Минимум 2 символа'
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Введите email'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      validator: (v) => (v == null || v.trim().length < 6)
                          ? 'Минимум 6 символов'
                          : null,
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 10),
                      SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(
                            value: UserRole.user,
                            label: Text('Клиент'),
                          ),
                          ButtonSegment(
                            value: UserRole.performer,
                            label: Text('Исполнитель'),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (value) =>
                            setState(() => _role = value.first),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(
                          _loading
                              ? 'Загрузка...'
                              : (_isLogin ? 'Войти' : 'Создать аккаунт'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? 'Нет аккаунта? Зарегистрироваться'
                            : 'Уже есть аккаунт? Войти',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
