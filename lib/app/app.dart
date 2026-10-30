
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
        return ValueListenableBuilder<double>(
          valueListenable: AppAppearance.textScaleNotifier,
          builder: (context, textScale, _) {
            final background = AppAppearance.colors[selectedColor];
            final baseTheme = AppTheme.light;

            return MaterialApp.router(
              title: 'TranVanToanKTGK',
              debugShowCheckedModeBanner: false,
              theme: baseTheme.copyWith(
                scaffoldBackgroundColor: background,
                appBarTheme: baseTheme.appBarTheme.copyWith(
                  backgroundColor: background,
                ),
              ),
              builder: (context, widget) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: widget ?? const SizedBox.shrink(),
                );
              },
              routerConfig: _router,
            );
          },
        );
      },
    );
  }
}
