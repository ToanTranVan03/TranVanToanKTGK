import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/session/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppSession.instance.restore();
  runApp(
    const ProviderScope(
      child: AttendanceApp(),
    ),
  );
}
