import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../session/app_session.dart';

/// Shared Dio client; phan Auth se bo sung interceptor JWT o giai doan sau.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.isConfigured ? ApiConfig.normalizedBaseUrl : '',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final token = AppSession.instance.token;
    if (AppSession.instance.isAuthenticated && token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = AppSession.instance;

        if (session.isAuthenticated && session.token != null) {
          options.headers['Authorization'] =
          'Bearer ${session.token}';
        }

        handler.next(options);
      },
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
