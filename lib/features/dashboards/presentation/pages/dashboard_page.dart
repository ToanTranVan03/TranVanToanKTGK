import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/session/app_session.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.role, super.key});
  final String role;

  @override
  Widget build(BuildContext context) {
    final heading = switch (role) {
      'ADMIN' => 'Quản trị hệ thống',
      'LECTURER' => 'Dashboard giảng viên',
      _ => 'Dashboard sinh viên',
    };
    final features = switch (role) {
      'ADMIN' => <(String, String, IconData)>[
        ('Phân quyền người dùng', '/admin/users', Icons.admin_panel_settings_outlined),
        ('Quản lý môn học', '/courses', Icons.menu_book_outlined),
        ('Quản lý phòng học', '/rooms', Icons.meeting_room_outlined),
        ('Quản lý lớp học', '/classes', Icons.groups_outlined),
        ('Quản lý sinh viên', '/students', Icons.person_outline),
        ('Duyệt đơn xin nghỉ', '/leaves', Icons.fact_check_outlined),
      ],
      'LECTURER' => <(String, String, IconData)>[
        ('Lớp giảng dạy và điểm danh', '/classes', Icons.groups_outlined),
        ('Danh sách môn học', '/courses', Icons.menu_book_outlined),
        ('Duyệt đơn xin nghỉ', '/leaves', Icons.fact_check_outlined),
      ],
      _ => <(String, String, IconData)>[
        ('Lớp học và điểm danh', '/classes', Icons.how_to_reg_outlined),
        ('Quét mã QR + vị trí GPS', '/qr/scan', Icons.qr_code_scanner),
        ('Lịch sử điểm danh', '/attendance-history', Icons.history_outlined),
        ('Gửi và xem đơn xin nghỉ', '/leaves', Icons.edit_note_outlined),
      ],
    };
    return Scaffold(
      appBar: AppBar(title: Text(heading), actions: [
        IconButton(tooltip: 'Đăng xuất', onPressed: () async {
          await AppSession.instance.signOut();
          if (context.mounted) context.go('/login');
        }, icon: const Icon(Icons.logout))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Xin chào, ${AppSession.instance.fullName ?? ''}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Đăng nhập Email OTP thành công · Quản lý điểm danh Phần 5: QR + GPS'),
        const SizedBox(height: 20),

        Card(
          child: ListTile(
            leading: const Icon(
              Icons.face_retouching_natural,
              color: Color(0xFF275DCE),
            ),
            title: const Text('Kích hoạt Face Unlock'),
            subtitle: const Text(
              'Đăng nhập nhanh bằng khuôn mặt trên thiết bị hỗ trợ',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/face-login'),
          ),
        ),

        const SizedBox(height: 12),

        for (final (title, path, icon) in features)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Card(child: ListTile(
              leading: Icon(icon, color: const Color(0xFF275DCE)),
              title: Text(title),
              subtitle: const Text('Dữ liệu trực tiếp từ PostgreSQL · Render API'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(path),
            )),
          ),
      ]),
    );
  }
}
