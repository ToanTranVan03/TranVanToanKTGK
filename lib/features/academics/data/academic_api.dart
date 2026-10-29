import 'package:dio/dio.dart';

class AcademicApi {
  AcademicApi(this.dio);
  final Dio dio;

  Future<List<Map<String, dynamic>>> list(String path) async {
    final result = await dio.get<List<dynamic>>('academics/$path');
    return (result.data ?? <dynamic>[])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> create(String path, Map<String, dynamic> body) async {
    await dio.post('academics/$path', data: body);
  }

  Future<void> update(String path, Map<String, dynamic> body) async {
    await dio.put('academics/$path', data: body);
  }

  Future<void> remove(String path) async {
    await dio.delete('academics/$path');
  }
}
