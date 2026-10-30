
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppAppearance {
  AppAppearance._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'selected_background';

  static const colors = <Color>[
    Color(0xFFF4F7FC), // Xanh trang nhat
    Color(0xFFE7F5F2), // Xanh ngoc
    Color(0xFFFFF2E5), // Cam kem
    Color(0xFFF3EDFC), // Tim nhat
    Color(0xFFFFFFFF), // Trang
  ];

  static const names = <String>[
    'Mặc định',
    'Xanh ngọc',
    'Cam kem',
    'Tím nhạt',
    'Trắng',
  ];

  static final selected = ValueNotifier<int>(0);

  static Color get background => colors[selected.value];

  static Future<void> restore() async {
    try {
      final saved = await _storage.read(key: _key);
      final index = int.tryParse(saved ?? '') ?? 0;

      if (index >= 0 && index < colors.length) {
        selected.value = index;
      }
    } catch (_) {
      selected.value = 0;
    }
  }

  static Future<void> change(int index) async {
    if (index < 0 || index >= colors.length) return;

    selected.value = index;

    await _storage.write(
      key: _key,
      value: index.toString(),
    );
  }
}
