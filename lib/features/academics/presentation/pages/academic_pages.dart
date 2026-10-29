import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/data/auth_api.dart';
import '../../data/academic_api.dart';

bool get _admin => AppSession.instance.role == 'ADMIN';
bool get _student => AppSession.instance.role == 'STUDENT';
String _value(dynamic value) => value?.toString() ?? '';

String _date(dynamic value) {
  final date = DateTime.tryParse(_value(value));
  if (date == null) return _value(value);
  final local = date.toLocal();
  String n(int i) => i.toString().padLeft(2, '0');
  return '${n(local.day)}/${n(local.month)}/${local.year} ${n(local.hour)}:${n(local.minute)}';
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    ) ?? false;

class AcademicError extends StatelessWidget {
  const AcademicError({required this.message, required this.retry, super.key});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off, size: 36),
        const SizedBox(height: 12), Text(message, textAlign: TextAlign.center),
        TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
      ]),
    ),
  );
}

class _TextField extends StatelessWidget {
  const _TextField(this.controller, this.label, {this.number = false, this.maxLines = 1});
  final TextEditingController controller;
  final String label;
  final bool number;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ),
  );
}

// ADMIN: CRUD courses and classrooms using the schema that already exists.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({required this.type, super.key});
  final String type;
  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> data = [];
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  bool get courses => widget.type == 'courses';

  @override
  void initState() { super.initState(); Future.microtask(reload); }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final items = await api.list(widget.type);
      if (mounted) setState(() => data = items);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: _value(row?['name']));
    final code = TextEditingController(text: _value(row?['code']));
    final credits = TextEditingController(text: _value(row?['credits']).isEmpty ? '3' : _value(row?['credits']));
    final lat = TextEditingController(text: _value(row?['latitude']).isEmpty ? '10.8231' : _value(row?['latitude']));
    final lon = TextEditingController(text: _value(row?['longitude']).isEmpty ? '106.6297' : _value(row?['longitude']));
    final radius = TextEditingController(text: _value(row?['radiusMeters']).isEmpty ? '100' : _value(row?['radiusMeters']));
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Thêm ${courses ? 'môn học' : 'phòng học'}' : 'Sửa thông tin'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (courses) _TextField(code, 'Mã môn'),
          _TextField(name, courses ? 'Tên môn học' : 'Tên phòng'),
          if (courses) _TextField(credits, 'Số tín chỉ', number: true),
          if (!courses) ...[
            _TextField(lat, 'Vĩ độ', number: true),
            _TextField(lon, 'Kinh độ', number: true),
            _TextField(radius, 'Bán kính (mét)', number: true),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () {
            final body = courses
              ? <String, dynamic>{'code': code.text.trim(), 'name': name.text.trim(), 'credits': int.tryParse(credits.text) ?? 0}
              : <String, dynamic>{'name': name.text.trim(), 'latitude': double.tryParse(lat.text) ?? 0,
                  'longitude': double.tryParse(lon.text) ?? 0, 'radiusMeters': double.tryParse(radius.text) ?? 0};
            Navigator.pop(ctx, body);
          }, child: const Text('Lưu')),
        ],
      ),
    );
    // Disposing here can conflict with the route's closing animation on some devices.
    if (payload == null || !mounted) return;
    try {
      if (row == null) { await api.create(widget.type, payload); }
      else { await api.update('${widget.type}/${row['id']}', payload); }
      if (mounted) _toast(context, 'Đã lưu thành công');
      await reload();
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }

  Future<void> delete(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Xóa ${row['name']}?')) return;
    try {
      await api.remove('${widget.type}/${row['id']}');
      await reload();
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(courses ? 'Quản lý môn học' : 'Quản lý phòng học'), actions: [
      IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: _admin ? FloatingActionButton.extended(
      onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Thêm mới')) : null,
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : RefreshIndicator(onRefresh: reload, child: ListView(padding: const EdgeInsets.all(16), children: [
          if (data.isEmpty) const ListTile(title: Text('Chưa có dữ liệu.')),
          for (final row in data) Card(child: ListTile(
            leading: Icon(courses ? Icons.menu_book_outlined : Icons.meeting_room_outlined),
            title: Text('${courses ? '${row['code']} · ' : ''}${row['name']}'),
            subtitle: Text(courses ? '${row['credits']} tín chỉ'
                : 'Vị trí: ${row['latitude']}, ${row['longitude']} · Bán kính ${row['radiusMeters']} m'),
            trailing: _admin ? PopupMenuButton<String>(onSelected: (value) =>
                value == 'edit' ? edit(row) : delete(row), itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ]) : null,
          )),
        ])),
  );
}

class ClassesPage extends ConsumerStatefulWidget {
  const ClassesPage({super.key});
  @override
  ConsumerState<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends ConsumerState<ClassesPage> {
  List<Map<String, dynamic>> classes = [], courses = [], rooms = [];
  bool loading = true;
  String? error;
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  @override
  void initState() { super.initState(); Future.microtask(reload); }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([api.list('classes'), api.list('courses'), api.list('rooms')]);
      if (mounted) setState(() { classes = results[0]; courses = results[1]; rooms = results[2]; });
    } catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    if (courses.isEmpty) { _toast(context, 'Hãy tạo môn học trước.'); return; }
    final code = TextEditingController(text: _value(row?['classCode']));
    final semester = TextEditingController(text: _value(row?['semester']).isEmpty ? 'HK1-2026' : _value(row?['semester']));
    var courseId = _value(row?['courseId']).isEmpty ? _value(courses.first['id']) : _value(row?['courseId']);
    var roomId = _value(row?['classroomId']);
    if (!courses.any((x) => x['id'] == courseId)) courseId = _value(courses.first['id']);
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text(row == null ? 'Tạo lớp học' : 'Sửa lớp học'),
        content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _TextField(code, 'Mã lớp'), _TextField(semester, 'Học kỳ'),
          DropdownButtonFormField<String>(initialValue: courseId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Môn học'),
            items: courses.map((x) => DropdownMenuItem(value: _value(x['id']),
                child: Text('${x['code']} · ${x['name']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (x) => setDialog(() => courseId = x ?? courseId)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: roomId.isEmpty ? '' : roomId,
            isExpanded: true, decoration: const InputDecoration(labelText: 'Phòng học'),
            items: [const DropdownMenuItem(value: '', child: Text('Chưa xếp phòng')),
              ...rooms.map((x) => DropdownMenuItem(value: _value(x['id']),
                child: Text(_value(x['name']))))],
            onChanged: (x) => setDialog(() => roomId = x ?? '')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {
            'classCode': code.text.trim(), 'semester': semester.text.trim(),
            'courseId': courseId, 'classroomId': roomId.isEmpty ? null : roomId,
          }), child: const Text('Lưu')),
        ],
      ),
    ));
    if (body == null || !mounted) return;
    try {
      if (row == null) { await api.create('classes', body); }
      else { await api.update('classes/${row['id']}', body); }
      await reload();
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Xóa lớp ${row['classCode']}?')) return;
    try { await api.remove('classes/${row['id']}'); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh sách lớp học'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    floatingActionButton: _admin ? FloatingActionButton.extended(onPressed: () => edit(),
      icon: const Icon(Icons.add), label: const Text('Tạo lớp')) : null,
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : RefreshIndicator(onRefresh: reload, child: ListView(padding: const EdgeInsets.all(16), children: [
          if (classes.isEmpty) const ListTile(title: Text('Chưa có lớp nào được phân quyền cho bạn.')),
          for (final row in classes) Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
            title: Text('${row['classCode']} · ${row['courseName']}'),
            subtitle: Text('${row['semester']} · ${row['roomName'] ?? ''} · ${row['studentCount']} sinh viên'),
            onTap: () => context.push('/classes/${row['id']}'),
            trailing: _admin ? PopupMenuButton<String>(onSelected: (x) =>
                x == 'edit' ? edit(row) : remove(row), itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa lớp')),
                PopupMenuItem(value: 'delete', child: Text('Xóa lớp')),
              ]) : const Icon(Icons.chevron_right),
          )),
        ])),
  );
}

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});
  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}
class _StudentsPageState extends ConsumerState<StudentsPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> students = [];
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  @override
  void initState() { super.initState(); Future.microtask(reload); }
  Future<void> reload() async {
    setState(() { loading = true; error = null; });
    try { final items = await api.list('students'); if (mounted) setState(() => students = items); }
    catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> edit(Map<String, dynamic> row) async {
    final name = TextEditingController(text: _value(row['fullName']));
    final studentCode = TextEditingController(text: _value(row['studentCode']));
    bool active = row['isActive'] == true;
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(title: const Text('Cập nhật sinh viên'),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_value(row['email'])), const SizedBox(height: 12),
          _TextField(name, 'Họ và tên'), _TextField(studentCode, 'Mã sinh viên'),
          SwitchListTile(title: const Text('Tài khoản hoạt động'), value: active,
            onChanged: (x) => setDialog(() => active = x)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {
            'fullName': name.text.trim(), 'studentCode': studentCode.text.trim(), 'isActive': active,
          }), child: const Text('Lưu'))],
      ),
    ));
    if (body == null || !mounted) return;
    try { await api.update('students/${row['id']}', body); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> deactivateStudent(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Vô hiệu hóa ${row['fullName']}? Lịch sử điểm danh sẽ được giữ lại.')) return;
    try { await api.remove('students/${row['id']}'); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý sinh viên'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : RefreshIndicator(onRefresh: reload, child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Sinh viên tự đăng ký và xác nhận Email OTP; quản trị viên chỉnh sửa hồ sơ, vô hiệu hóa và xếp lớp.'),
          const SizedBox(height: 12),
          if (students.isEmpty) const ListTile(title: Text('Chưa có tài khoản sinh viên.')),
          for (final row in students) Card(child: ListTile(
            title: Text('${row['fullName']} (${row['studentCode'] ?? row['userName']})'),
            subtitle: Text('${row['email']} · ${row['isActive'] == true ? 'Đang hoạt động' : 'Đã khóa'}'),
            trailing: PopupMenuButton<String>(onSelected: (x) => x == 'edit' ? edit(row) : deactivateStudent(row),
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Sửa thông tin')),
                PopupMenuItem(value: 'delete', child: Text('Vô hiệu hóa'))]),
          )),
        ])),
  );
}

// Class detail: enrollment, lecturer assignment and session navigation.
class ClassDetailPage extends ConsumerStatefulWidget {
  const ClassDetailPage({required this.classId, super.key});
  final String classId;
  @override
  ConsumerState<ClassDetailPage> createState() => _ClassDetailPageState();
}
class _ClassDetailPageState extends ConsumerState<ClassDetailPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> roster = [], assigned = [], lecturers = [];
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  @override
  void initState() { super.initState(); Future.microtask(reload); }
  Future<void> reload() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final teachers = await api.list('classes/${widget.classId}/lecturers');
      final students = _student ? <Map<String, dynamic>>[] :
          await api.list('classes/${widget.classId}/students');
      final available = _admin ? await api.list('lecturers') : <Map<String, dynamic>>[];
      if (mounted) setState(() { assigned = teachers; roster = students; lecturers = available; });
    } catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> addStudent() async {
    final username = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm sinh viên vào lớp'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Nhập chính xác tên đăng nhập của sinh viên đã đăng ký và xác nhận email.'),
        const SizedBox(height: 12), _TextField(username, 'Tên đăng nhập (Username)'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, username.text.trim()), child: const Text('Thêm'))],
    ));
    if (result == null || result.isEmpty || !mounted) return;
    try {
      final found = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          'academics/students/lookup', queryParameters: {'username': result});
      final studentId = _value(found.data?['id']);
      await api.create('classes/${widget.classId}/students', {'studentId': studentId});
      await reload();
      if (mounted) _toast(context, 'Đã thêm sinh viên');
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> removeStudent(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Loại ${row['fullName']} khỏi lớp?')) return;
    try { await api.remove('classes/${widget.classId}/students/${row['id']}'); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> addLecturer() async {
    final candidates = lecturers.where((x) => !assigned.any((y) => y['id'] == x['id'])).toList();
    if (candidates.isEmpty) { _toast(context, 'Chưa có giảng viên để phân công. Hãy cấp vai trò LECTURER trước.'); return; }
    var id = _value(candidates.first['id']);
    final chosen = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(title: const Text('Phân công giảng viên'),
        content: DropdownButtonFormField<String>(initialValue: id, isExpanded: true,
          items: candidates.map((x) => DropdownMenuItem(value: _value(x['id']),
            child: Text(_value(x['fullName'])))).toList(),
          onChanged: (x) => setDialog(() => id = x ?? id)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, id), child: const Text('Phân công'))],
      ),
    ));
    if (chosen == null || !mounted) return;
    try { await api.create('classes/${widget.classId}/lecturers', {'lecturerId': chosen}); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> removeLecturer(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Hủy phân công ${row['fullName']}?')) return;
    try { await api.remove('classes/${widget.classId}/lecturers/${row['id']}'); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết lớp học'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(leading: const Icon(Icons.event_note), title: const Text('Các buổi điểm danh'),
          subtitle: const Text('Xem, tạo, sửa phiên và điểm danh'),
          onTap: () => context.push('/classes/${widget.classId}/sessions'), trailing: const Icon(Icons.chevron_right))),
        const SizedBox(height: 16),
        Row(children: [const Expanded(child: Text('Giảng viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          if (_admin) IconButton(tooltip: 'Phân công giảng viên', onPressed: addLecturer, icon: const Icon(Icons.person_add_alt_1))]),
        if (assigned.isEmpty) const ListTile(title: Text('Chưa phân công giảng viên.')),
        for (final row in assigned) ListTile(leading: const Icon(Icons.school_outlined),
          title: Text(_value(row['fullName'])),
          trailing: _admin ? IconButton(onPressed: () => removeLecturer(row), icon: const Icon(Icons.remove_circle_outline)) : null),
        if (!_student) ...[
          const Divider(height: 28),
          Row(children: [const Expanded(child: Text('Danh sách sinh viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Thêm sinh viên', onPressed: addStudent, icon: const Icon(Icons.person_add))]),
          if (roster.isEmpty) const ListTile(title: Text('Lớp chưa có sinh viên.')),
          for (final row in roster) Card(child: ListTile(
            title: Text(_value(row['fullName'])),
            subtitle: Text('${row['studentCode'] ?? row['userName']} · ${row['email']}'),
            trailing: IconButton(tooltip: 'Loại khỏi lớp', icon: const Icon(Icons.person_remove_outlined),
              onPressed: () => removeStudent(row)),
          )),
        ],
      ]),
  );
}

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({required this.classId, super.key});
  final String classId;
  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}
class _SessionsPageState extends ConsumerState<SessionsPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> sessions = [];
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  @override
  void initState() { super.initState(); Future.microtask(reload); }
  Future<void> reload() async {
    setState(() { loading = true; error = null; });
    try { final data = await api.list('classes/${widget.classId}/sessions');
      if (mounted) setState(() => sessions = data); }
    catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> edit([Map<String, dynamic>? row]) async {
    final now = DateTime.now();
    DateTime start = DateTime.tryParse(_value(row?['startsAtUtc']))?.toLocal() ?? now.subtract(const Duration(minutes: 5));
    DateTime end = DateTime.tryParse(_value(row?['endsAtUtc']))?.toLocal() ?? now.add(const Duration(hours: 1));
    String status = _value(row?['status']).isEmpty ? 'DRAFT' : _value(row?['status']);
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) {
        Future<void> choose(bool beginning) async {
          final old = beginning ? start : end;
          final day = await showDatePicker(context: ctx, initialDate: old,
            firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (day == null || !ctx.mounted) return;
          final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(old));
          if (time == null || !ctx.mounted) return;
          final date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
          setDialog(() { if (beginning) { start = date; } else { end = date; } });
        }
        return AlertDialog(title: Text(row == null ? 'Tạo buổi điểm danh' : 'Sửa buổi điểm danh'),
          content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: const Text('Bắt đầu'), subtitle: Text(_date(start.toIso8601String())),
              trailing: const Icon(Icons.calendar_month), onTap: () => choose(true)),
            ListTile(title: const Text('Kết thúc'), subtitle: Text(_date(end.toIso8601String())),
              trailing: const Icon(Icons.calendar_month), onTap: () => choose(false)),
            DropdownButtonFormField<String>(initialValue: status,
              decoration: const InputDecoration(labelText: 'Trạng thái phiên'),
              items: const [
                DropdownMenuItem(value: 'DRAFT', child: Text('Nháp')),
                DropdownMenuItem(value: 'OPEN', child: Text('Đang mở')),
                DropdownMenuItem(value: 'CLOSED', child: Text('Đã đóng')),
              ], onChanged: (x) => setDialog(() => status = x ?? status)),
            const SizedBox(height: 8),
            const Text('Để sinh viên điểm danh thử nghiệm, chọn Đang mở và đặt thời gian bao gồm hiện tại.'),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, {
              'startsAtUtc': start.toUtc().toIso8601String(),
              'endsAtUtc': end.toUtc().toIso8601String(), 'status': status,
            }), child: const Text('Lưu'))],
        );
      },
    ));
    if (body == null || !mounted) return;
    try {
      if (row == null) { await api.create('classes/${widget.classId}/sessions', body); }
      else { await api.update('sessions/${row['id']}', body); }
      await reload();
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> remove(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Xóa phiên điểm danh này?')) return;
    try { await api.remove('sessions/${row['id']}'); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Phiên điểm danh'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    floatingActionButton: !_student ? FloatingActionButton.extended(onPressed: () => edit(),
      icon: const Icon(Icons.add), label: const Text('Tạo phiên')) : null,
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : RefreshIndicator(onRefresh: reload, child: ListView(padding: const EdgeInsets.all(16), children: [
          if (sessions.isEmpty) const ListTile(title: Text('Chưa có phiên điểm danh.')),
          for (final row in sessions) Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.event_available_outlined),
              title: Text('${_date(row['startsAtUtc'])} → ${_date(row['endsAtUtc'])}'),
              subtitle: Text('Trạng thái: ${row['status']} · Có mặt: ${row['presentCount']}'),
              onTap: () => context.push('/classes/${widget.classId}/sessions/${row['id']}'),
              trailing: const Icon(Icons.chevron_right)),
            if (!_student) OverflowBar(children: [
              TextButton.icon(onPressed: () => edit(row), icon: const Icon(Icons.edit_outlined), label: const Text('Sửa')),
              TextButton.icon(onPressed: () => remove(row), icon: const Icon(Icons.delete_outline), label: const Text('Xóa')),
            ]),
          ])),
        ])),
  );
}

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({required this.classId, required this.sessionId, super.key});
  final String classId;
  final String sessionId;
  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}
class _AttendancePageState extends ConsumerState<AttendancePage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> records = [], roster = [];
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  @override
  void initState() { super.initState(); Future.microtask(reload); }
  Future<void> reload() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await api.list('sessions/${widget.sessionId}/attendance');
      final students = _student ? <Map<String, dynamic>>[] : await api.list('classes/${widget.classId}/students');
      if (mounted) setState(() { records = data; roster = students; });
    } catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> checkIn() async {
    try {
      await api.create('sessions/${widget.sessionId}/check-in', {});
      if (mounted) _toast(context, 'Đã ghi nhận điểm danh thử nghiệm.');
      await reload();
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> mark(Map<String, dynamic> student) async {
    final current = records.where((x) => x['studentId'] == student['id']).toList();
    var status = current.isEmpty ? 'PRESENT' : _value(current.first['status']);
    final chosen = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(title: Text('Điểm danh: ${student['fullName']}'),
        content: DropdownButtonFormField<String>(initialValue: status,
          decoration: const InputDecoration(labelText: 'Kết quả'),
          items: const [
            DropdownMenuItem(value: 'PRESENT', child: Text('Có mặt')),
            DropdownMenuItem(value: 'LATE', child: Text('Đi trễ')),
            DropdownMenuItem(value: 'ABSENT', child: Text('Vắng')),
            DropdownMenuItem(value: 'EXCUSED', child: Text('Vắng có phép')),
          ], onChanged: (x) => setDialog(() => status = x ?? status)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, status), child: const Text('Lưu kết quả'))],
      ),
    ));
    if (chosen == null || !mounted) return;
    try { await api.update('sessions/${widget.sessionId}/attendance/${student['id']}', {'status': chosen}); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kết quả điểm danh'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : ListView(padding: const EdgeInsets.all(16), children: [
          if (_student) ...[
            const Text('Điểm danh thủ công để kiểm thử CRUD. Ở Phần 5 sẽ thay bằng QR/GPS có xác thực.'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: checkIn, icon: const Icon(Icons.check_circle_outline),
              label: const Text('Điểm danh thử nghiệm')),
            const SizedBox(height: 20),
            if (records.isEmpty) const ListTile(title: Text('Bạn chưa có kết quả điểm danh.')),
            for (final row in records) ListTile(title: Text(_value(row['status'])),
              subtitle: Text('Phương thức: ${row['method']} · ${_date(row['checkedAtUtc'])}')),
          ] else ...[
            Text('Sinh viên: ${roster.length} · Đã nhập kết quả: ${records.length}',
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (roster.isEmpty) const ListTile(title: Text('Chưa có sinh viên trong lớp.')),
            for (final student in roster) Builder(builder: (context) {
              final found = records.where((x) => x['studentId'] == student['id']).toList();
              return Card(child: ListTile(
                title: Text(_value(student['fullName'])),
                subtitle: Text(found.isEmpty ? 'Chưa ghi nhận' : _value(found.first['status'])),
                trailing: const Icon(Icons.edit_outlined), onTap: () => mark(student),
              ));
            }),
          ],
        ]),
  );
}

class LeavesPage extends ConsumerStatefulWidget {
  const LeavesPage({super.key});
  @override
  ConsumerState<LeavesPage> createState() => _LeavesPageState();
}
class _LeavesPageState extends ConsumerState<LeavesPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> leaves = [];
  AcademicApi get api => AcademicApi(ref.read(apiClientProvider));
  @override
  void initState() { super.initState(); Future.microtask(reload); }
  Future<void> reload() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try { final data = await api.list('leave-requests'); if (mounted) setState(() => leaves = data); }
    catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> create() async {
    try {
      final classes = await api.list('classes');
      final all = <Map<String, dynamic>>[];
      for (final c in classes) {
        final sessions = await api.list('classes/${c['id']}/sessions');
        for (final s in sessions) {
          all.add({...s, 'className': _value(c['classCode'])});
        }
      }
      if (!mounted) return;
      if (all.isEmpty) { _toast(context, 'Bạn chưa có buổi học để gửi đơn xin nghỉ.'); return; }
      final reason = TextEditingController();
      var sessionId = _value(all.first['id']);
      final body = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(title: const Text('Gửi đơn xin nghỉ học'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: sessionId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Buổi học'),
              items: all.map((s) => DropdownMenuItem(value: _value(s['id']),
                child: Text('${s['className']} · ${_date(s['startsAtUtc'])}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (x) => setDialog(() => sessionId = x ?? sessionId)),
            const SizedBox(height: 14), _TextField(reason, 'Lý do xin nghỉ', maxLines: 4),
          ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, {
              'attendanceSessionId': sessionId, 'reason': reason.text.trim(),
            }), child: const Text('Gửi đơn'))],
        ),
      ));
      if (body == null || !mounted) return;
      await api.create('leave-requests', body);
      await reload();
      if (mounted) _toast(context, 'Đã gửi đơn xin nghỉ học');
    } catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> edit(Map<String, dynamic> row) async {
    final reason = TextEditingController(text: _value(row['reason']));
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sửa lý do xin nghỉ'),
      content: SizedBox(width: 360, child: _TextField(reason, 'Lý do', maxLines: 4)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, reason.text.trim()), child: const Text('Lưu'))],
    ));
    if (value == null || !mounted) return;
    try { await api.update('leave-requests/${row['id']}', {'reason': value}); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> remove(Map<String, dynamic> row) async {
    if (!await _confirm(context, 'Thu hồi đơn xin nghỉ này?')) return;
    try { await api.remove('leave-requests/${row['id']}'); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  Future<void> decide(Map<String, dynamic> row, String status) async {
    if (!await _confirm(context, status == 'APPROVED' ? 'Duyệt đơn xin nghỉ?' : 'Từ chối đơn xin nghỉ?')) return;
    try { await api.update('leave-requests/${row['id']}/decision', {'status': status}); await reload(); }
    catch (e) { if (mounted) _toast(context, errorText(e)); }
  }
  String label(String status) => switch (status) {
    'APPROVED' => 'Đã duyệt', 'REJECTED' => 'Đã từ chối', _ => 'Chờ xử lý',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_student ? 'Đơn xin nghỉ của tôi' : 'Duyệt đơn xin nghỉ'),
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    floatingActionButton: _student ? FloatingActionButton.extended(
      onPressed: create, icon: const Icon(Icons.add), label: const Text('Gửi đơn')) : null,
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? AcademicError(message: error!, retry: reload)
      : RefreshIndicator(onRefresh: reload, child: ListView(padding: const EdgeInsets.all(16), children: [
          if (leaves.isEmpty) const ListTile(title: Text('Chưa có đơn xin nghỉ học.')),
          for (final row in leaves) Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: [
            ListTile(leading: const Icon(Icons.edit_note),
              title: Text('${row['classCode']} · ${_date(row['startsAtUtc'])}'),
              subtitle: Text('${_student ? '' : '${row['studentName']} · '}${label(_value(row['status']))}\n${row['reason']}')),
            if (_value(row['status']) == 'PENDING') OverflowBar(children: _student
              ? [TextButton.icon(onPressed: () => edit(row), icon: const Icon(Icons.edit), label: const Text('Sửa')),
                  TextButton.icon(onPressed: () => remove(row), icon: const Icon(Icons.delete_outline), label: const Text('Thu hồi'))]
              : [TextButton.icon(onPressed: () => decide(row, 'REJECTED'),
                  icon: const Icon(Icons.close), label: const Text('Từ chối')),
                  FilledButton.icon(onPressed: () => decide(row, 'APPROVED'),
                    icon: const Icon(Icons.check), label: const Text('Duyệt'))]),
          ]))),
        ])),
  );
}
