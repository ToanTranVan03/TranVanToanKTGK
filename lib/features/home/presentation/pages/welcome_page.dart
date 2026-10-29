import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../backend_status/presentation/widgets/backend_connection_card.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh sinh viên'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: const Color(0xFFE4ECFF),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 55,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'STUDENT ATTENDANCE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hệ thống điểm danh sinh viên thông minh',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: const [
                        _FeatureTile(
                          icon: Icons.verified_user_outlined,
                          title: 'Bảo mật tài khoản',
                          subtitle: 'Đăng nhập, OTP và OAuth 2.0',
                        ),
                        Divider(height: 1, indent: 70, endIndent: 16),
                        _FeatureTile(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Điểm danh thông minh',
                          subtitle: 'QR động, GPS và khuôn mặt',
                        ),
                        Divider(height: 1, indent: 70, endIndent: 16),
                        _FeatureTile(
                          icon: Icons.bluetooth_rounded,
                          title: 'AI và Bluetooth',
                          subtitle: 'Phát hiện hiện diện và cảnh báo học tập',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const BackendConnectionCard(),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Bắt đầu'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'TranVanToanKTGK  •  Giai đoạn 3',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8090A7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EFFD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}
