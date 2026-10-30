import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_appearance.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/data/auth_api.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _username = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('auth/me');

      final profile = response.data ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _username = '${profile['username'] ?? ''}';
        _email = '${profile['email'] ?? ''}';
        _name.text = '${profile['fullName'] ?? ''}';
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final newName = _name.text.trim();

    if (newName.length < 2 || newName.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Họ tên phải có từ 2 đến 200 ký tự.'),
        ),
      );
      return;
    }

    if (_saving) return;

    setState(() => _saving = true);

    try {
      await ref.read(apiClientProvider).put(
        'auth/me',
        data: {'fullName': newName},
      );

      await AppSession.instance.updateFullName(newName);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hồ sơ thành công.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt tài khoản'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Giao diện',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chọn màu nền ứng dụng',
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<int>(
                          valueListenable: AppAppearance.selected,
                          builder: (context, selected, _) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (int i = 0;
                                    i < AppAppearance.colors.length;
                                    i++)
                                  InkWell(
                                    onTap: () async {
                                      await AppAppearance.change(i);
                                    },
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    child: Tooltip(
                                      message: AppAppearance.names[i],
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppAppearance.colors[i],
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: selected == i
                                                ? Colors.blue
                                                : Colors.grey.shade300,
                                            width: selected == i ? 3 : 1,
                                          ),
                                        ),
                                        child: selected == i
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.blue,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Kích thước chữ (Cỡ chữ)',
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<double>(
                          valueListenable: AppAppearance.textScaleNotifier,
                          builder: (context, currentScale, _) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (int i = 0;
                                    i < AppAppearance.textScales.length;
                                    i++)
                                  ChoiceChip(
                                    label: Text(AppAppearance.textScaleNames[i]),
                                    selected: currentScale == AppAppearance.textScales[i],
                                    onSelected: (selected) async {
                                      if (selected) {
                                        await AppAppearance.changeTextScale(
                                          AppAppearance.textScales[i],
                                        );
                                      }
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Hồ sơ cá nhân',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadProfile,
                            child: const Text('Tải lại hồ sơ'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          initialValue: _username,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Tên đăng nhập',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: _email,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _name,
                          maxLength: 200,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving || _error != null
                              ? null
                              : _saveProfile,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _saving
                                ? 'Đang lưu...'
                                : 'Lưu thay đổi',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tên đăng nhập và email không thể đổi tại đây. '
                  'Email cần xác minh OTP khi muốn thay đổi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}
