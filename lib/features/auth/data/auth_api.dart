import 'package:dio/dio.dart';

class AuthApi {
  AuthApi(this.dio);
  final Dio dio;

  Future<void> register({
    required String username,
    required String email,
    required String fullName,
    required String password,
  }) async {
    await dio.post('auth/register', data: {
      'username': username, 'email': email, 'fullName': fullName, 'password': password,
    });
  }

  Future<void> verifyEmail(String email, String code) async {
    await dio.post('auth/verify-email', data: {'email': email, 'code': code});
  }

  Future<void> resendEmail(String email) async {
    await dio.post('auth/resend-email', data: {'email': email});
  }

  Future<Map<String, dynamic>> passwordLogin(String username, String password) async {
    final response = await dio.post<Map<String, dynamic>>('auth/login',
        data: {'username': username, 'password': password});
    return response.data!;
  }

  Future<Map<String, dynamic>> verifyLoginOtp(String ticket, String code) async {
    final response = await dio.post<Map<String, dynamic>>('auth/otp/verify',
        data: {'ticket': ticket, 'code': code});
    return response.data!;
  }
}

String errorText(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (error.response?.statusCode == 401) return 'Sai thông tin đăng nhập hoặc tài khoản bị khóa.';
    if (error.response?.statusCode == 429) return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
    if (error.response?.statusCode == 503) return 'Dịch vụ chưa sẵn sàng hoặc Email OTP chưa cấu hình.';
    if (error.response?.statusCode != null) return 'Máy chủ trả về lỗi ${error.response!.statusCode}.';
    return 'Không kết nối được API. Kiểm tra Internet hoặc đường dẫn API.';
  }
  return 'Có lỗi xảy ra. Vui lòng thử lại.';
}
