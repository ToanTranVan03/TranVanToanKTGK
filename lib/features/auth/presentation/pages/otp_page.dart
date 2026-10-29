import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
import '../../data/auth_api.dart';

enum OtpPurpose { confirmEmail, login }

class OtpArguments {
  const OtpArguments._(this.purpose, this.email, this.ticket, this.emailHint);
  final OtpPurpose purpose;
  final String? email;
  final String? ticket;
  final String emailHint;
  factory OtpArguments.emailConfirmation(String email) =>
      OtpArguments._(OtpPurpose.confirmEmail, email, null, email);
  factory OtpArguments.login({required String ticket, required String emailHint}) =>
      OtpArguments._(OtpPurpose.login, null, ticket, emailHint);
}

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({required this.arguments, super.key});
  final OtpArguments arguments;
  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _code = TextEditingController();
  bool _busy = false;
  @override
  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6 || _busy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã OTP gồm 6 chữ số.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final api = AuthApi(ref.read(apiClientProvider));
      if (widget.arguments.purpose == OtpPurpose.confirmEmail) {
        await api.verifyEmail(widget.arguments.email!, _code.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xác nhận email. Vui lòng đăng nhập.')));
        context.go('/login');
      } else {
        final data = await api.verifyLoginOtp(widget.arguments.ticket!, _code.text.trim());
        await AppSession.instance.signIn(data);
        if (mounted) context.go(AppSession.instance.homePath);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _resend() async {
    final email = widget.arguments.email;
    if (email == null) return;
    try {
      await AuthApi(ref.read(apiClientProvider)).resendEmail(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nếu tài khoản hợp lệ, OTP đã được yêu cầu gửi lại.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác thực OTP')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.mark_email_read_outlined, size: 72, color: Color(0xFF275DCE)),
        const SizedBox(height: 20),
        const Text('Nhập mã xác thực', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Mã 6 chữ số đã được gửi tới ${widget.arguments.emailHint}', textAlign: TextAlign.center),
        const SizedBox(height: 26),
        TextField(controller: _code, keyboardType: TextInputType.number,
          maxLength: 6, decoration: const InputDecoration(labelText: 'Mã OTP')),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Đang xác minh...' : 'Xác nhận OTP')),
        if (widget.arguments.purpose == OtpPurpose.confirmEmail)
          TextButton(onPressed: _resend, child: const Text('Gửi lại OTP xác nhận')),
      ]),
    ))),
  );
}
