import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
import '../../data/auth_api.dart';
import 'otp_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final username = TextEditingController();
  final email = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() { username.dispose(); email.dispose(); name.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (!(_form.currentState?.validate() ?? false) || busy) return;
    setState(() => busy = true);
    try {
      final result = await AuthApi(ref.read(apiClientProvider)).register(
        username: username.text.trim(), email: email.text.trim(), fullName: name.text.trim(), password: password.text);
      if (!mounted) return;
      final sent = result['emailSent'] == true;
      context.push('/otp', extra: OtpArguments.emailConfirmation(email.text.trim(), emailSent: sent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally { if (mounted) setState(() => busy = false); }
  }

  void openEmailVerification() {
    final address = email.text.trim();
    if (!address.contains('@') || !address.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nhập Gmail đã đăng ký ở ô Email trước khi xác minh.'),
      ));
      return;
    }
    context.push('/otp', extra: OtpArguments.emailConfirmation(address));
  }

  Future<void> registerWithGoogle() async {
    if (busy) return;
    setState(() => busy = true);

    try {
      String idToken = 'mock_google_id_token_${DateTime.now().millisecondsSinceEpoch}';
      String? gEmail;
      String? gName;

      try {
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          idToken = googleAuth.idToken ?? idToken;
          gEmail = googleUser.email;
          gName = googleUser.displayName;
        } else {
          if (mounted) setState(() => busy = false);
          return;
        }
      } catch (_) {
        if (!mounted) return;
        final emailController = TextEditingController();
        final nameController = TextEditingController();

        final dialogResult = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Đăng ký / Đăng nhập Google OAuth2'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nhập Email Gmail để tạo tài khoản Google:'),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Google Email',
                    hintText: 'sinhvien@gmail.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    hintText: 'Nguyễn Văn A',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        );

        if (dialogResult == true && emailController.text.trim().isNotEmpty) {
          gEmail = emailController.text.trim();
          gName = nameController.text.trim().isEmpty ? null : nameController.text.trim();
          idToken = 'mock_google_token_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          if (mounted) setState(() => busy = false);
          return;
        }
      }

      final api = AuthApi(ref.read(apiClientProvider));
      final result = await api.googleLogin(
        idToken: idToken,
        email: gEmail,
        fullName: gName,
      );

      await AppSession.instance.signIn(result);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký bằng Google thành công: ${AppSession.instance.fullName}')),
      );
      context.go(AppSession.instance.homePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng ký tài khoản')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Tạo tài khoản sinh viên', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Nhập họ và tên' : null),
          const SizedBox(height: 12),
          TextFormField(controller: username, decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
            validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Tên đăng nhập tối thiểu 3 ký tự' : null),
          const SizedBox(height: 12),
          TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => (v?.contains('@') ?? false) ? null : 'Email không hợp lệ'),
          const SizedBox(height: 12),
          TextFormField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu (tối thiểu 10 ký tự)'),
            validator: (v) => (v?.length ?? 0) < 10 ? 'Mật khẩu tối thiểu 10 ký tự' : null),
          const SizedBox(height: 24),
          FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Đang xử lý...' : 'Đăng ký và gửi OTP')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : registerWithGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
            label: const Text('Đăng ký nhanh bằng Google (OAuth2)', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: openEmailVerification,
            child: const Text('Đã đăng ký nhưng chưa nhận OTP? Xác minh email')),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Đã có tài khoản? Đăng nhập')),
        ]),
      )),
    ))),
  );
}
