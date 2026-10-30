import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-facing role switches are convenience only. Backend validates every JWT.
class AppSession extends ChangeNotifier {
  AppSession._();
  static final AppSession instance = AppSession._();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? token;
  String? fullName;
  String? role;
  DateTime? expiresAtUtc;

  bool get isAuthenticated => token != null &&
      expiresAtUtc != null && DateTime.now().toUtc().isBefore(expiresAtUtc!);

  String get homePath => switch (role) {
        'ADMIN' => '/admin',
        'LECTURER' => '/lecturer',
        _ => '/student',
      };

  Future<void> restore() async {
    try {
      token = await _storage.read(key: 'access_token');
      role = await _storage.read(key: 'user_role');
      fullName = await _storage.read(key: 'user_name');
      final savedExpiry = await _storage.read(key: 'expires_at');
      expiresAtUtc = savedExpiry == null ? null : DateTime.tryParse(savedExpiry)?.toUtc();
      if (!isAuthenticated) {
        token = null;
        role = null;
        fullName = null;
      }
    } catch (_) {
      token = null;
      role = null;
      fullName = null;
    }
    notifyListeners();
  }

  Future<void> signIn(Map<String, dynamic> response) async {
    final user = Map<String, dynamic>.from(response['user'] as Map);
    token = response['accessToken'] as String;
    role = user['role'] as String? ?? 'STUDENT';
    fullName = user['fullName'] as String? ?? '';
    expiresAtUtc = DateTime.parse(response['expiresAtUtc'] as String).toUtc();
    await _storage.write(key: 'access_token', value: token);
    await _storage.write(key: 'user_role', value: role);
    await _storage.write(key: 'user_name', value: fullName);
    await _storage.write(key: 'expires_at', value: expiresAtUtc!.toIso8601String());
    notifyListeners();
  }

  Future<void> signOut() async {
    token = null;
    role = null;
    fullName = null;
    expiresAtUtc = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'expires_at');
    notifyListeners();
  }

  Future<void> updateFullName(String newName) async {
    fullName = newName.trim();
    await _storage.write(key: 'user_name', value: fullName);
    notifyListeners();
  }
}
