import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../data/auth_api.dart';
import 'otp_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    if (!ApiConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chưa cấu hình API HTTPS. Xem README-PHAN-3.md.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final api = AuthApi(ref.read(apiClientProvider));
      final result = await api.passwordLogin(_username.text.trim(), _password.text);
      if (!mounted) return;
      context.push('/otp', extra: OtpArguments.login(
        ticket: result['ticket'] as String,
        emailHint: result['emailHint'] as String? ?? '',
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Đăng nhập')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.verified_user_outlined, size: 74, color: Color(0xFF275DCE)),
                    const SizedBox(height: 16),
                    const Text('Chào mừng trở lại!', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 28),
                    TextFormField(controller: _username, textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên đăng nhập' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _password, obscureText: _hidden,
                      decoration: InputDecoration(labelText: 'Mật khẩu', prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(onPressed: () => setState(() => _hidden = !_hidden),
                          icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
                      validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                      onFieldSubmitted: (_) => _login()),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: _busy ? null : _login,
                      child: Text(_busy ? 'Đang gửi OTP...' : 'Đăng nhập')),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => context.push('/register'),
                      child: const Text('Chưa có tài khoản? Đăng ký')),
                    const SizedBox(height: 6),
                    const Text('Sau khi nhập đúng mật khẩu, mã OTP sẽ được gửi qua email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
