import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';

/// Shared Dio client; phan Auth se bo sung interceptor JWT o giai doan sau.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.isConfigured ? ApiConfig.normalizedBaseUrl : '',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});
