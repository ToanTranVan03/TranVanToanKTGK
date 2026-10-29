
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/data/auth_api.dart';

class AttendanceRiskPage extends ConsumerStatefulWidget {
  const AttendanceRiskPage({super.key});

  @override
  ConsumerState<AttendanceRiskPage> createState() =>
      _AttendanceRiskPageState();
}

class _AttendanceRiskPageState
    extends ConsumerState<AttendanceRiskPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref
          .read(apiClientProvider)
          .get<List<dynamic>>('analytics/attendance-risk');

      final items = (response.data ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _reports = items;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = errorText(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _levelName(String level) {
    return switch (level) {
      'HIGH' => 'Nguy cơ cao',
      'MEDIUM' => 'Cần chú ý',
      'LOW' => 'Ổn định',
      _ => 'Chưa đủ dữ liệu',
    };
  }

  Color _levelColor(String level) {
    return switch (level) {
      'HIGH' => Colors.red.shade700,
      'MEDIUM' => Colors.orange.shade800,
      'LOW' => Colors.green.shade700,
      _ => Colors.blueGrey,
    };
  }

  int _count(Map<String, dynamic> item, String key) {
    return (item[key] as num?)?.toInt() ?? 0;
  }

  Widget _reportCard(Map<String, dynamic> item) {
    final level = '${item['riskLevel'] ?? 'INSUFFICIENT'}';
    final color = _levelColor(level);

    final rate = (item['attendanceRate'] as num?)?.toDouble() ?? 0;

    final isStudent = AppSession.instance.role == 'STUDENT';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['classCode']} - ${item['courseName']}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isStudent) ...[
              const SizedBox(height: 6),
              Text(
                'Sinh viên: ${item['studentName']}'
                    ' (${item['studentCode'] ?? 'Chưa có MSSV'})',
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${rate.toStringAsFixed(1)}% chuyên cần',
                    style: TextStyle(
                      color: color,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _levelName(level),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              'Có mặt: ${_count(item, 'present')}'
                  '   |   Đi muộn: ${_count(item, 'late')}',
            ),
            const SizedBox(height: 6),
            Text(
              'Vắng: ${_count(item, 'absent')}'
                  '   |   Có phép: ${_count(item, 'excused')}',
            ),
            const SizedBox(height: 6),
            Text(
              'Buổi đã kết thúc: '
                  '${_count(item, 'completedSessions')}',
            ),
            const SizedBox(height: 6),
            Text(
              'Buổi chưa ghi nhận: '
                  '${_count(item, 'unrecordedSessions')}',
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    level == 'HIGH'
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item['message']}',
                      style: TextStyle(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = AppSession.instance.role == 'STUDENT';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo chuyên cần'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Cập nhật',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              isStudent
                  ? 'Chuyên cần của tôi'
                  : 'Theo dõi chuyên cần sinh viên',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Phân tích từ các buổi điểm danh '
                  'đã kết thúc trong PostgreSQL.',
            ),
            const SizedBox(height: 16),
            if (_reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Chưa có dữ liệu chuyên cần. '
                        'Hãy tạo lớp, thêm sinh viên '
                        'và thực hiện điểm danh.',
                  ),
                ),
              ),
            for (final item in _reports)
              _reportCard(item),
            const SizedBox(height: 16),
            const Text(
              'Ngưỡng cảnh báo chỉ phục vụ '
                  'minh họa đồ án, không phải '
                  'quy định học vụ chính thức.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
