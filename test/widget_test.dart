import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tran_van_toan_ktgk/app/app.dart';

void main() {
  testWidgets('Welcome page navigates to login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AttendanceApp()));

    await tester.pumpAndSettle();

    expect(find.text('STUDENT ATTENDANCE'), findsOneWidget);

    // Cuon nut Bat dau vao man hinh truoc khi bam.
    final startButton = find.widgetWithText(FilledButton, 'Bắt đầu');

    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Kiem tra da chuyen sang trang dang nhap.
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
  });

  testWidgets('Login page validates empty fields', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AttendanceApp()));

    await tester.pumpAndSettle();

    // Chuyen tu Welcome sang Login.
    final startButton = find.widgetWithText(FilledButton, 'Bắt đầu');

    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Tim nut Dang nhap.
    final submit = find.widgetWithText(FilledButton, 'Đăng nhập');

    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    // Bam khi chua nhap username va password.
    await tester.tap(submit);
    await tester.pumpAndSettle();

    // Kiem tra thong bao validation.
    expect(find.text('Vui lòng nhập tên đăng nhập'), findsOneWidget);

    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });
}
