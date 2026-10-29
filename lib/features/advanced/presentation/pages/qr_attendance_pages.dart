import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../widgets/location_gate.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_api.dart';
import '../../data/advanced_attendance_api.dart';

/// Staff displays a fresh server-signed QR. Never generate signatures on the phone.
class SessionQrPage extends ConsumerStatefulWidget {
  const SessionQrPage({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<SessionQrPage> createState() => _SessionQrPageState();
}

class _SessionQrPageState extends ConsumerState<SessionQrPage> {
  Map<String, dynamic>? _qr;
  String? _error;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 35), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await AdvancedAttendanceApi(ref.read(apiClientProvider))
          .issueQr(widget.sessionId);

      if (mounted) {
        setState(() {
          _qr = result;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _qr = null;
          _error = errorText(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = _qr?['qrToken'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã QR phiên điểm danh'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            tooltip: 'Lấy mã mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading && token == null) const CircularProgressIndicator(),
              if (_error != null) ...[
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Thử lại')),
              ],
              if (token != null) ...[
                const Text(
                  'Giảng viên đưa QR cho sinh viên quét',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: token,
                      size: 270,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Phòng: ${_qr?['roomName']} · Bán kính: ${_qr?['radiusMeters']} m',
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã chỉ có hiệu lực 60 giây, tự làm mới mỗi 35 giây.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token));

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép mã (chỉ Debug).'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy mã để kiểm thử emulator'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Student scans a QR, grants foreground location, and sends both to Render.
class QrGpsScanPage extends ConsumerStatefulWidget {
  const QrGpsScanPage({super.key});

  @override
  ConsumerState<QrGpsScanPage> createState() => _QrGpsScanPageState();
}

class _QrGpsScanPageState extends ConsumerState<QrGpsScanPage> {
  bool _submitting = false;
  String? _result;
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  Future<void> _submit(String token) async {
    if (_submitting || !mounted) return;
    if (!token.startsWith('AT5.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR không phải mã điểm danh của ứng dụng.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('GPS đang tắt. Hãy bật Location trên thiết bị.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Chưa cấp quyền vị trí. Hãy bật quyền Location trong Settings.',
        );
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      final response = await AdvancedAttendanceApi(ref.read(apiClientProvider))
          .checkIn(
            qrToken: token,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
          );
      if (!mounted) return;
      setState(
        () => _result =
            (response['message'] as String?) ?? 'Điểm danh thành công.',
      );
    } catch (error) {
      if (!mounted) return;
      final msg = error is StateError ? error.message : errorText(error);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(child: Text('Không thể điểm danh')),
            ],
          ),
          content: Text(msg.toString()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _manualToken() async {
    final field = TextEditingController();
    try {
      final token = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dán mã QR (Debug)'),
          content: TextField(
            controller: field,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'AT5....'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, field.text.trim()),
              child: const Text('Kiểm tra GPS và điểm danh'),
            ),
          ],
        ),
      );
      if (token != null && token.isNotEmpty && mounted) await _submit(token);
    } finally {
      field.dispose();
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocationGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Quét QR + GPS')),
      body: _result != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 68,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(_result!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Về danh sách phiên'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _camera,
                        onDetect: (capture) {
                          if (capture.barcodes.isEmpty) return;
                          final raw = capture.barcodes.first.rawValue;
                          if (raw != null) _submit(raw);
                        },
                      ),
                      const Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: 190,
                          color: Colors.white60,
                        ),
                      ),
                      if (_submitting)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Quét mã từ giảng viên; ứng dụng sẽ xin quyền GPS và gửi lên máy chủ.',
                        textAlign: TextAlign.center,
                      ),
                      if (kDebugMode)
                        TextButton.icon(
                          onPressed: _submitting ? null : _manualToken,
                          icon: const Icon(Icons.paste),
                          label: const Text('Dán mã để kiểm thử máy ảo'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
