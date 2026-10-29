import 'package:dio/dio.dart';

class AdvancedAttendanceApi {
  AdvancedAttendanceApi(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> issueQr(String sessionId) async {
    final response = await dio.get<Map<String, dynamic>>(
      'advanced-attendance/sessions/$sessionId/qr',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> checkIn({
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      'advanced-attendance/check-in',
      data: {
        'qrToken': qrToken,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
      },
    );
    return response.data ?? <String, dynamic>{};
  }
}
