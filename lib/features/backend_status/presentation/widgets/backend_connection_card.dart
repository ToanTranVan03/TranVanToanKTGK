import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';

/// Part 2: real HTTP check to a publicly deployed HTTPS backend.
/// The request runs only when the user presses the button.
class BackendConnectionCard extends ConsumerStatefulWidget {
  const BackendConnectionCard({super.key});

  @override
  ConsumerState<BackendConnectionCard> createState() =>
      _BackendConnectionCardState();
}

class _BackendConnectionCardState extends ConsumerState<BackendConnectionCard> {
  bool _checking = false;
  String? _result;
  bool _connected = false;

  Future<void> _checkConnection() async {
    if (!ApiConfig.isConfigured || _checking) return;

    setState(() {
      _checking = true;
      _result = null;
      _connected = false;
    });

    try {
      final response = await ref.read(apiClientProvider)
          .get<Map<String, dynamic>>('system/status');
      final data = response.data;
      final dbConnected = data?['databaseConnected'] == true;
      if (!mounted) return;
      setState(() {
        _connected = dbConnected;
        _result = dbConnected
            ? 'Đã kết nối API và PostgreSQL thành công.'
            : 'API phản hồi nhưng PostgreSQL chưa sẵn sàng.';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      setState(() {
        _result = status != null
            ? 'Máy chủ trả về HTTP $status. Hãy kiểm tra Backend.'
            : 'Không kết nối được API. Kiểm tra URL, mạng và deploy.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = 'Lỗi khi kiểm tra Backend.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ApiConfig.isConfigured;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _connected ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                  color: _connected
                      ? const Color(0xFF178258)
                      : const Color(0xFF96710B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    configured ? 'Backend HTTPS đã được khai báo' : 'Chưa cấu hình Backend',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              configured
                  ? ApiConfig.baseUrl
                  : 'Deploy API lên Internet rồi cấu hình API_BASE_URL.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_result != null) ...[
              const SizedBox(height: 9),
              Text(
                _result!,
                style: TextStyle(
                  fontSize: 12,
                  color: _connected
                      ? const Color(0xFF178258)
                      : const Color(0xFFB45309),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: configured && !_checking ? _checkConnection : null,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(_checking ? 'Đang kết nối...' : 'Kiểm tra kết nối Backend'),
            ),
          ],
        ),
      ),
    );
  }
}
