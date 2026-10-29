import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
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

  // =====================================================
  // DANG NHAP BANG USERNAME VA PASSWORD
  // =====================================================

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) {
      return;
    }

    if (!ApiConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa cấu hình API HTTPS. Xem README-PHAN-3.md.'),
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final api = AuthApi(ref.read(apiClientProvider));

      final result = await api.passwordLogin(
        _username.text.trim(),
        _password.text,
      );

      if (!mounted) {
        return;
      }

      // Dang nhap dung -> chuyen sang OTP dang nhap
      context.push(
        '/otp',
        extra: OtpArguments.login(
          ticket: result['ticket'] as String,
          emailHint: result['emailHint'] as String? ?? '',
        ),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      final data = error.response?.data;

      // Tai khoan dung mat khau nhung chua xac minh email
      if (data is Map &&
          data['code'] == 'EMAIL_NOT_CONFIRMED' &&
          data['email'] is String &&
          (data['email'] as String).isNotEmpty) {
        final address = data['email'] as String;

        // Thu gui lai OTP xac nhan email
        try {
          await AuthApi(ref.read(apiClientProvider)).resendEmail(address);
        } catch (resendError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Chưa gửi được OTP: ${errorText(resendError)}'),
              ),
            );
          }
        }

        if (!mounted) {
          return;
        }

        // Van mo man hinh xac minh de nguoi dung
        // co the bam Gui lai OTP thu cong
        context.push('/otp', extra: OtpArguments.emailConfirmation(address));
      } else {
        // Cac loi khac: sai mat khau, tai khoan, API...
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorText(error))));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // =====================================================
  // XAC MINH EMAIL DOI VOI TAI KHOAN CHUA XAC NHAN
  // =====================================================

  Future<void> _recoverEmail() async {
    if (_busy) {
      return;
    }

    final field = TextEditingController();

    try {
      final address = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Xác minh tài khoản'),
            content: TextField(
              controller: field,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Gmail đã dùng đăng ký',
                hintText: 'example@gmail.com',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, field.text.trim());
                },
                child: const Text('Tiếp tục'),
              ),
            ],
          );
        },
      );

      if (!mounted || address == null) {
        return;
      }

      if (!address.contains('@') || !address.contains('.')) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gmail chưa hợp lệ.')));
        return;
      }

      setState(() {
        _busy = true;
      });

      // Gui lai OTP xac nhan email
      try {
        final api = AuthApi(ref.read(apiClientProvider));

        await api.resendEmail(address);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chưa gửi được OTP: ${errorText(error)}')),
          );
        }
      }

      if (!mounted) {
        return;
      }

      // Mo man hinh nhap OTP du gui email thanh cong
      // hay can nguoi dung bam Gui lai OTP
      context.push('/otp', extra: OtpArguments.emailConfirmation(address));
    } finally {
      field.dispose();

      if (mounted && _busy) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // =====================================================
  // DANG NHAP GOOGLE OAUTH2
  // =====================================================

  Future<void> _loginWithGoogle() async {
    if (_busy) return;
    if (!ApiConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa cấu hình API HTTPS. Xem README-PHAN-3.md.')),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      String idToken = 'mock_google_id_token_${DateTime.now().millisecondsSinceEpoch}';
      String? email;
      String? name;

      try {
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          idToken = googleAuth.idToken ?? idToken;
          email = googleUser.email;
          name = googleUser.displayName;
        } else {
          if (mounted) setState(() => _busy = false);
          return;
        }
      } catch (_) {
        if (!mounted) return;
        final emailController = TextEditingController();
        final nameController = TextEditingController();

        final dialogResult = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Đăng nhập Google OAuth2'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nhập Email Gmail để mô phỏng Google Sign-In:'),
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
                child: const Text('Đăng nhập'),
              ),
            ],
          ),
        );

        if (dialogResult == true && emailController.text.trim().isNotEmpty) {
          email = emailController.text.trim();
          name = nameController.text.trim().isEmpty ? null : nameController.text.trim();
          idToken = 'mock_google_token_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          if (mounted) setState(() => _busy = false);
          return;
        }
      }

      final api = AuthApi(ref.read(apiClientProvider));
      final result = await api.googleLogin(
        idToken: idToken,
        email: email,
        fullName: name,
      );

      await AppSession.instance.signIn(result);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập Google thành công: ${AppSession.instance.fullName}')),
      );
      context.go(AppSession.instance.homePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // =====================================================
  // GIAO DIEN DANG NHAP
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 74,
                      color: Color(0xFF275DCE),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Chào mừng trở lại!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // TEN DANG NHAP
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên đăng nhập';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // MAT KHAU
                    TextFormField(
                      controller: _password,
                      obscureText: _hidden,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hidden = !_hidden;
                            });
                          },
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        _login();
                      },
                    ),

                    const SizedBox(height: 24),

                    // NUT DANG NHAP
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: Text(_busy ? 'Đang xử lý...' : 'Đăng nhập'),
                    ),

                    const SizedBox(height: 12),

                    // HOAC DANG NHAP BANG GOOGLE
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('hoặc', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // NUT DANG NHAP GOOGLE
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                      label: const Text(
                        'Đăng nhập bằng Google (OAuth2)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // CHUYEN SANG DANG KY
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              context.push('/register');
                            },
                      child: const Text('Chưa có tài khoản? Đăng ký'),
                    ),

                    const SizedBox(height: 4),

                    // GUI LAI OTP XAC MINH EMAIL
                    TextButton(
                      onPressed: _busy ? null : _recoverEmail,
                      child: const Text('Chưa xác nhận Gmail? Gửi lại mã OTP'),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Sau khi nhập đúng mật khẩu, '
                      'mã OTP sẽ được gửi qua email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
