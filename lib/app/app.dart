
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_appearance.dart';
import 'theme/app_theme.dart';

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    AppAppearance.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppAppearance.selected,
      builder: (context, selectedColor, child) {
        final background = AppAppearance.colors[selectedColor];
        final baseTheme = AppTheme.light;

        return MaterialApp.router(
          title: 'TranVanToanKTGK',
          debugShowCheckedModeBanner: false,

          // Mau nen theo lua chon cua nguoi dung.
          theme: baseTheme.copyWith(
            scaffoldBackgroundColor: background,
            appBarTheme: baseTheme.appBarTheme.copyWith(
              backgroundColor: background,
            ),
          ),

          // Giu nguyen Router cua ung dung.
          routerConfig: _router,
        );
      },
    );
  }
}
