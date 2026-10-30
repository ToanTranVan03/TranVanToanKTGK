import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/app_session.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.role, super.key});

  final String role;

  static const Color primary = Color(0xFF3156C8);
  static const Color background = Color(0xFFF4F7FC);

  @override
  Widget build(BuildContext context) {
    final heading = switch (role) {
      'ADMIN' => 'Quản trị hệ thống',
      'LECTURER' => 'Dashboard giảng viên',
      _ => 'Dashboard sinh viên',
    };

    final roleName = switch (role) {
      'ADMIN' => 'Quản trị viên',
      'LECTURER' => 'Giảng viên',
      _ => 'Sinh viên',
    };

    final features = switch (role) {
      'ADMIN' => <(String, String, IconData)>[
        (
          'Phân quyền người dùng',
          '/admin/users',
          Icons.admin_panel_settings_outlined,
        ),
        ('Quản lý môn học', '/courses', Icons.menu_book_outlined),
        ('Quản lý phòng học', '/rooms', Icons.meeting_room_outlined),
        ('Quản lý lớp học', '/classes', Icons.groups_outlined),
        ('Quản lý sinh viên', '/students', Icons.person_outline),
        ('Duyệt đơn xin nghỉ', '/leaves', Icons.fact_check_outlined),
        ('Cảnh báo chuyên cần', '/attendance-risk', Icons.insights_outlined),
      ],
      'LECTURER' => <(String, String, IconData)>[
        ('Lớp giảng dạy và điểm danh', '/classes', Icons.groups_outlined),
        ('Danh sách môn học', '/courses', Icons.menu_book_outlined),
        ('Duyệt đơn xin nghỉ', '/leaves', Icons.fact_check_outlined),
        ('Cảnh báo chuyên cần', '/attendance-risk', Icons.insights_outlined),
      ],
      _ => <(String, String, IconData)>[
        ('Lớp học và điểm danh', '/classes', Icons.how_to_reg_outlined),
        ('Quét QR + GPS', '/qr/scan', Icons.qr_code_scanner_outlined),
        ('Lịch sử điểm danh', '/attendance-history', Icons.history_outlined),
        ('Đơn xin nghỉ học', '/leaves', Icons.edit_note_outlined),
        ('Cảnh báo chuyên cần', '/attendance-risk', Icons.insights_outlined),
      ],
    };

    const colors = <Color>[
      Color(0xFF2B65D9),
      Color(0xFF0E9583),
      Color(0xFF8B59CA),
      Color(0xFFE18A28),
      Color(0xFF2A88C1),
      Color(0xFFD65F82),
      Color(0xFF5275D0),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          heading,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B2B4B),
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            color: const Color(0xFF304878),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            color: const Color(0xFF304878),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Đăng xuất?'),
                  content: const Text(
                    'Bạn có muốn đăng xuất khỏi tài khoản hiện tại?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );

              if (confirm != true || !context.mounted) {
                return;
              }

              await AppSession.instance.signOut();

              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // Header chao mung
                _buildWelcomeHeader(roleName),

                const SizedBox(height: 24),

                const Text(
                  'Bảo mật tài khoản',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2B4B),
                  ),
                ),

                const SizedBox(height: 12),

                _buildFaceUnlockCard(context),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Danh mục chức năng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B2B4B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5ECFC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${features.length} mục',
                        style: const TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth >= 650
                        ? 4
                        : constraints.maxWidth >= 480
                        ? 3
                        : 2;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: features.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 148,
                      ),
                      itemBuilder: (context, index) {
                        final (title, path, icon) = features[index];

                        return _buildFeatureCard(
                          context,
                          title: title,
                          path: path,
                          icon: icon,
                          color: colors[index % colors.length],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String roleName) {
    final fullName = AppSession.instance.fullName;

    final displayName = fullName == null || fullName.trim().isEmpty
        ? 'Bạn'
        : fullName.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2547A5), Color(0xFF416DE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -55,
            child: Container(
              width: 165,
              height: 165,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            right: 25,
            bottom: -65,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'STUDENT ATTENDANCE',
                      style: TextStyle(
                        color: Color(0xFFDDE7FF),
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Xin chào, $displayName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    roleName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceUnlockCard(BuildContext context) {
    return Material(
      color: const Color(0xFFF0EDFF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/face-login'),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDFD9FA)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.face_retouching_natural,
                color: Color(0xFF6853BA),
                size: 29,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Kích hoạt Face Unlock',
                  style: TextStyle(
                    color: Color(0xFF32266E),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF6853BA)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String path,
    required IconData icon,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0xFF8AA1C9).withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(path),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EDF7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: color, size: 25),
                  ),
                  const Icon(
                    Icons.north_east_rounded,
                    color: Color(0xFF9AA8BF),
                    size: 19,
                  ),
                ],
              ),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243453),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
