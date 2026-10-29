import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
import '../../data/auth_api.dart';

class FaceLoginPage extends ConsumerStatefulWidget {
  const FaceLoginPage({super.key});

  @override
  ConsumerState<FaceLoginPage> createState() => _FaceLoginPageState();
}

class _FaceLoginPageState extends ConsumerState<FaceLoginPage> {
  final LocalAuthentication _biometric = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _busy = false;
  String? _message;

  static const _usernameKey = 'face_login_username';
  static const _secretKey = 'face_login_secret';

  Future<void> _verifyFace() async {
    final biometrics = await _biometric.getAvailableBiometrics();

    final hasFace = biometrics.contains(BiometricType.face);

    // Chỉ cho phép test vân tay khi chạy Debug.
    // Bản Release vẫn yêu cầu Face Unlock thực sự.
    final allowDebugFingerprint =
        kDebugMode && biometrics.contains(BiometricType.fingerprint);

    if (!hasFace && !allowDebugFingerprint) {
      throw StateError(
        'Thiết bị chưa có Face Unlock khả dụng. '
        'Nếu đang dùng Pixel 8 Emulator, hãy đăng ký '
        'vân tay giả lập để kiểm thử trong chế độ Debug. '
        'Hoặc sử dụng điện thoại hỗ trợ Face Unlock.',
      );
    }

    final verified = await _biometric.authenticate(
      localizedReason: hasFace
          ? 'Xác minh khuôn mặt để sử dụng Student Attendance'
          : 'Kiểm thử đăng nhập sinh trắc học bằng vân tay giả lập',
      biometricOnly: true,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );

    if (!verified) {
      throw StateError('Xác thực sinh trắc học không thành công.');
    }
  }

  Future<void> _enroll() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (!AppSession.instance.isAuthenticated) {
        throw StateError('Bạn phải đăng nhập bằng Email OTP trước.');
      }

      await _verifyFace();

      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>('auth/face/enroll');

      final data = response.data;

      if (data == null ||
          data['username'] is! String ||
          data['secret'] is! String) {
        throw StateError('Backend trả thông tin không hợp lệ.');
      }

      await _storage.write(
        key: _usernameKey,
        value: data['username'] as String,
      );

      await _storage.write(key: _secretKey, value: data['secret'] as String);

      if (!mounted) return;

      setState(() {
        _message =
            'Đã kích hoạt Face Unlock. '
            'Bạn có thể đăng xuất để thử đăng nhập khuôn mặt.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = error is StateError ? error.message : errorText(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signIn() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final username = await _storage.read(key: _usernameKey);
      final secret = await _storage.read(key: _secretKey);

      if (username == null || secret == null) {
        throw StateError(
          'Thiết bị này chưa kích hoạt Face Unlock. '
          'Hãy đăng nhập Email OTP và kích hoạt trước.',
        );
      }

      await _verifyFace();

      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            'auth/face/sign-in',
            data: {'username': username, 'secret': secret},
          );

      final data = response.data;
      if (data == null) {
        throw StateError('Không nhận được phiên đăng nhập.');
      }

      await AppSession.instance.signIn(data);

      if (!mounted) return;
      context.go(AppSession.instance.homePath);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = error is StateError ? error.message : errorText(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await ref.read(apiClientProvider).post('auth/face/revoke');

      await _storage.delete(key: _usernameKey);
      await _storage.delete(key: _secretKey);

      if (!mounted) return;

      setState(() {
        _message = 'Đã tắt Face Unlock trên thiết bị này.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = errorText(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AppSession.instance.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập khuôn mặt')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.face_retouching_natural,
                    size: 100,
                    color: Color(0xFF275DCE),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loggedIn
                        ? 'Kích hoạt đăng nhập khuôn mặt'
                        : 'Chào mừng trở lại!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loggedIn
                        ? 'Xác thực khuôn mặt trên thiết bị '
                              'để kích hoạt đăng nhập nhanh.'
                        : 'Sử dụng Face Unlock đã kích hoạt '
                              'để đăng nhập tài khoản.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),
                  if (loggedIn) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _enroll,
                      icon: const Icon(Icons.verified_user),
                      label: const Text('Kích hoạt Face Unlock'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _revoke,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Tắt Face Unlock'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: const Icon(Icons.face),
                      label: const Text('Đăng nhập bằng khuôn mặt'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Đăng nhập bằng Email OTP'),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 18),
                    Text(_message!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Chỉ hỗ trợ thiết bị báo có sinh trắc học '
                    'khuôn mặt. Khóa đăng nhập thiết bị có hạn '
                    '7 ngày và có thể thu hồi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
