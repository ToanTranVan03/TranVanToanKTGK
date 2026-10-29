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
      'ADMIN' => ['Quản lý người dùng và phân quyền', 'Quản lý lớp học', 'Cấu hình hệ thống'],
      'LECTURER' => ['Danh sách lớp giảng dạy', 'Tạo phiên điểm danh', 'Thống kê chuyên cần'],
      _ => ['Điểm danh', 'Lịch sử vắng học', 'Đơn xin nghỉ học'],
    };
    return Scaffold(
      appBar: AppBar(title: Text(heading), actions: [
        IconButton(tooltip: 'Đăng xuất', onPressed: () async {
          await AppSession.instance.signOut();
          if (context.mounted) context.go('/login');
        }, icon: const Icon(Icons.logout))
      ]),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        Text('Xin chào, ${AppSession.instance.fullName ?? ''}',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Bạn đã đăng nhập và xác minh Email OTP thành công.'),
        const SizedBox(height: 20),
        for (final feature in features) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(child: ListTile(
            leading: const Icon(Icons.check_circle_outline, color: Color(0xFF275DCE)),
            title: Text(feature),
            subtitle: const Text('Chức năng nghiệp vụ triển khai ở Phần 4'),
          )),
        ),
        if (role == 'ADMIN') OutlinedButton.icon(
          onPressed: () => context.push('/admin/users'),
          icon: const Icon(Icons.manage_accounts), label: const Text('Quản lý phân quyền người dùng')),
      ]),
    );
  }
}
