import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_api.dart';
import '../../data/academic_api.dart';

// Phan 4: Lich su diem danh CUA SINH VIEN.
// API tren server loc lop hoc va ket qua diem danh theo JWT cua nguoi dung.
class AttendanceHistoryPage extends ConsumerStatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  ConsumerState<AttendanceHistoryPage> createState() =>
      _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends ConsumerState<AttendanceHistoryPage> {
  bool loading = true;
  String? error;
  bool hasClasses = false;
  List<_HistoryEntry> entries = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(reload);
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = AcademicApi(ref.read(apiClientProvider));
      final classes = await api.list('classes');
      final result = <_HistoryEntry>[];
      final now = DateTime.now().toUtc();

      for (final classRow in classes) {
        final classId = '${classRow['id'] ?? ''}';
        if (classId.isEmpty) continue;
        final sessions = await api.list('classes/$classId/sessions');
        for (final session in sessions) {
          final startsAt = DateTime.tryParse('${session['startsAtUtc'] ?? ''}');
          // Lich su chi bao gom cac buoi da bat dau.
          if (startsAt == null || startsAt.toUtc().isAfter(now)) continue;
          final sessionId = '${session['id'] ?? ''}';
          if (sessionId.isEmpty) continue;

          final records = await api.list('sessions/$sessionId/attendance');
          if (records.isEmpty) {
            // Khong suy dien vang mat khi chua co ban ghi diem danh.
            result.add(_HistoryEntry(
              courseName: '${classRow['courseName'] ?? ''}',
              classCode: '${classRow['classCode'] ?? ''}',
              startsAt: startsAt,
              status: 'NOT_RECORDED',
              method: '',
              checkedAt: null,
            ));
          } else {
            // Server chi tra ban ghi cua sinh vien dang dang nhap.
            for (final record in records) {
              result.add(_HistoryEntry(
                courseName: '${classRow['courseName'] ?? ''}',
                classCode: '${classRow['classCode'] ?? ''}',
                startsAt: startsAt,
                status: '${record['status'] ?? 'NOT_RECORDED'}',
                method: '${record['method'] ?? ''}',
                checkedAt: DateTime.tryParse('${record['checkedAtUtc'] ?? ''}'),
              ));
            }
          }
        }
      }

      result.sort((a, b) => b.startsAt.compareTo(a.startsAt));
      if (!mounted) return;
      setState(() {
        hasClasses = classes.isNotEmpty;
        entries = result;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = entries.where((e) => e.status == 'PRESENT').length;
    final lateCount = entries.where((e) => e.status == 'LATE').length;
    final absentCount = entries.where((e) => e.status == 'ABSENT').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử điểm danh'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 36),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    TextButton.icon(
                      onPressed: reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!hasClasses)
                        const ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Bạn chưa được phân vào lớp học.'),
                          subtitle: Text('Quản trị viên cần thêm bạn vào lớp để xem lịch sử điểm danh.'),
                        )
                      else if (entries.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.history),
                          title: Text('Chưa có lịch sử điểm danh.'),
                          subtitle: Text('Lớp học chưa có buổi điểm danh đã bắt đầu.'),
                        )
                      else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tổng hợp điểm danh',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Có mặt: $presentCount  ·  Đi muộn: $lateCount  ·  Vắng: $absentCount'),
                                const SizedBox(height: 4),
                                const Text('Buổi chưa có kết quả sẽ không được tự động tính là vắng.'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in entries)
                          Card(
                            child: ListTile(
                              leading: Icon(_statusIcon(entry.status)),
                              title: Text('${entry.courseName} · ${entry.classCode}'),
                              subtitle: Text(
                                'Buổi học: ${_date(entry.startsAt)}\n'
                                '${entry.checkedAt != null ? 'Điểm danh: ${_date(entry.checkedAt!)}' : 'Chưa có thời gian điểm danh'}'
                                '${entry.method.isEmpty ? '' : '\nPhương thức: ${entry.method}'}',
                              ),
                              isThreeLine: true,
                              trailing: Text(_statusLabel(entry.status),
                                  textAlign: TextAlign.right),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.courseName,
    required this.classCode,
    required this.startsAt,
    required this.status,
    required this.method,
    required this.checkedAt,
  });

  final String courseName;
  final String classCode;
  final DateTime startsAt;
  final String status;
  final String method;
  final DateTime? checkedAt;
}

String _date(DateTime value) {
  final d = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(d.day)}/${pad(d.month)}/${d.year} ${pad(d.hour)}:${pad(d.minute)}';
}

String _statusLabel(String code) => switch (code) {
  'PRESENT' => 'Có mặt',
  'LATE' => 'Đi muộn',
  'ABSENT' => 'Vắng',
  'EXCUSED' => 'Có phép',
  _ => 'Chưa ghi nhận',
};

IconData _statusIcon(String code) => switch (code) {
  'PRESENT' => Icons.check_circle_outline,
  'LATE' => Icons.schedule,
  'ABSENT' => Icons.cancel_outlined,
  'EXCUSED' => Icons.event_available_outlined,
  _ => Icons.help_outline,
};
