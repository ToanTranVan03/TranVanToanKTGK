import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tran_van_toan_ktgk/features/backend_status/presentation/widgets/backend_connection_card.dart';

void main() {
  testWidgets('Backend card displays HTTPS setup state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: BackendConnectionCard()),
        ),
      ),
    );
    expect(find.text('Kiểm tra kết nối Backend'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    // Without --dart-define, no unexpected network request may be issued.
    expect(button.onPressed, isNull);
  });
}
