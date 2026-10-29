import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tran_van_toan_ktgk/app/app.dart';

void main() {
  testWidgets('Welcome page navigates to login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AttendanceApp()),
    );

    expect(find.text('STUDENT ATTENDANCE'), findsOneWidget);

    // Nut "Bat dau" nam cuoi ListView va co the chua duoc build khi test.
    // scrollUntilVisible cuon va tao widget truoc khi tap.
    final startButton = find.text('Bắt đầu');
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
  });

  testWidgets('Login page validates empty fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AttendanceApp()),
    );

    final startButton = find.text('Bắt đầu');
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    final submit = find.text('Kiểm tra biểu mẫu');
    await tester.scrollUntilVisible(
      submit,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tên đăng nhập'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });
}
