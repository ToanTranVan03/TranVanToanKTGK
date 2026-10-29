import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationGate extends StatefulWidget {
  const LocationGate({required this.child, super.key});

  final Widget child;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _ready = false;
  bool _serviceOff = false;
  bool _deniedForever = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocation(requestPermission: false);
    }
  }

  Future<void> _checkLocation({bool requestPermission = true}) async {
    if (!mounted) return;

    setState(() => _checking = true);

    try {
      final service = await Geolocator.isLocationServiceEnabled();

      if (!service) {
        if (!mounted) return;
        setState(() {
          _ready = false;
          _serviceOff = true;
          _deniedForever = false;
          _message = 'Hãy bật dịch vụ vị trí trên điện thoại.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      final allowed =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      setState(() {
        _serviceOff = false;
        _ready = allowed;
        _deniedForever = permission == LocationPermission.deniedForever;
        _message = allowed
            ? ''
            : 'Ứng dụng cần quyền truy cập vị trí để điểm danh.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _message = 'Không kiểm tra được GPS: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _openSettings() async {
    if (_serviceOff) {
      await Geolocator.openLocationSettings();
    } else if (_deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await _checkLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_ready) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu vị trí')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 90,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 20),
              const Text(
                'Cần bật vị trí để điểm danh',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(_message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.location_on),
                  label: Text(
                    _serviceOff
                        ? 'Mở dịch vụ vị trí'
                        : _deniedForever
                        ? 'Mở cài đặt ứng dụng'
                        : 'Cấp quyền vị trí',
                  ),
                ),
              ),
              TextButton(
                onPressed: _checkLocation,
                child: const Text('Tôi đã bật vị trí'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
