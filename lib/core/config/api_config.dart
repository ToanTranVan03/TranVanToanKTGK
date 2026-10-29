/// Truyen qua --dart-define, KHONG hardcode endpoint noi bo hay bi mat.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get normalizedBaseUrl =>
      baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  static bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    // Backend bat buoc duoc deploy ra Internet, khong su dung localhost.
    const forbiddenHosts = {'localhost', '127.0.0.1', '10.0.2.2', '::1'};
    return !forbiddenHosts.contains(uri.host.toLowerCase());
  }
}
