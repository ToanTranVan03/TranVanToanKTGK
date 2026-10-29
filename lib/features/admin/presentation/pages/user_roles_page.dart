import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_api.dart';

class UserRolesPage extends ConsumerStatefulWidget {
  const UserRolesPage({super.key});
  @override
  ConsumerState<UserRolesPage> createState() => _UserRolesPageState();
}

class _UserRolesPageState extends ConsumerState<UserRolesPage> {
  List<Map<String, dynamic>>? users;
  String? error;
  bool loading = false;

  @override
  void initState() { super.initState(); Future.microtask(load); }

  Future<void> load() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final data = await ref.read(apiClientProvider).get<List<dynamic>>('admin/users');
      if (mounted) setState(() => users = (data.data ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> changeRole(String id, String role) async {
    try {
      await ref.read(apiClientProvider).put('admin/users/$id/role', data: {'role': role});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Phân quyền người dùng'), actions: [
      IconButton(onPressed: load, icon: const Icon(Icons.refresh))
    ]),
    body: loading && users == null ? const Center(child: CircularProgressIndicator()) :
      error != null ? Center(child: Text(error!)) : ListView(
        padding: const EdgeInsets.all(16),
        children: [for (final user in users ?? <Map<String,dynamic>>[])
          Card(child: ListTile(
            title: Text('${user['fullName'] ?? ''} (${user['userName'] ?? ''})'),
            subtitle: Text('${user['email'] ?? ''}'),
            trailing: DropdownButton<String>(
              value: ((user['roles'] as List?)?.isNotEmpty == true)
                  ? ((user['roles'] as List).first as String) : 'STUDENT',
              items: const ['STUDENT', 'LECTURER', 'ADMIN'].map((role) =>
                  DropdownMenuItem(value: role, child: Text(role))).toList(),
              onChanged: (role) { if (role != null) changeRole(user['id'] as String, role); },
            ),
          )),
        ],
      ),
  );
}
