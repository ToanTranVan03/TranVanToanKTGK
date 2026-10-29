import 'package:go_router/go_router.dart';

import '../../core/session/app_session.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/admin/presentation/pages/user_roles_page.dart';
import '../../features/dashboards/presentation/pages/dashboard_page.dart';
import '../../features/home/presentation/pages/welcome_page.dart';
import '../../features/academics/presentation/pages/academic_pages.dart';
import '../../features/academics/presentation/pages/attendance_history_page.dart';
import '../../features/advanced/presentation/pages/qr_attendance_pages.dart';
import '../../features/auth/presentation/pages/face_login_page.dart';
import '../../features/analytics/presentation/pages/attendance_risk_page.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  refreshListenable: AppSession.instance,

  redirect: (context, state) {
    final path = state.uri.path;

    // Cac trang bat buoc phai dang nhap
    final protectedRoute =
        path == '/admin' ||
        path == '/student' ||
        path == '/lecturer' ||
        path.startsWith('/admin/') ||
        path == '/courses' ||
        path == '/rooms' ||
        path == '/students' ||
        path == '/classes' ||
        path.startsWith('/classes/') ||
        path == '/leaves' ||
        path == '/attendance-history' ||
        path == '/attendance-risk' || // PHAN 7
        path == '/qr/scan' ||
        path.startsWith('/sessions/');

    // Chua dang nhap thi chuyen ve Login
    if (protectedRoute && !AppSession.instance.isAuthenticated) {
      return '/login';
    }

    // Chi ADMIN duoc vao quan tri va quan ly sinh vien
    if (protectedRoute &&
        (path.startsWith('/admin') || path == '/students') &&
        AppSession.instance.role != 'ADMIN') {
      return AppSession.instance.homePath;
    }

    // Kiem tra Dashboard giang vien
    if (protectedRoute &&
        path == '/lecturer' &&
        AppSession.instance.role != 'LECTURER') {
      return AppSession.instance.homePath;
    }

    // Kiem tra Dashboard sinh vien
    if (protectedRoute &&
        path == '/student' &&
        AppSession.instance.role != 'STUDENT') {
      return AppSession.instance.homePath;
    }

    // Chi sinh vien duoc quet QR
    if (path == '/qr/scan' && AppSession.instance.role != 'STUDENT') {
      return AppSession.instance.homePath;
    }

    // Sinh vien khong duoc quan ly phien diem danh
    if (path.startsWith('/sessions/') &&
        AppSession.instance.role == 'STUDENT') {
      return AppSession.instance.homePath;
    }

    // Chi sinh vien xem lich su diem danh ca nhan
    if (path == '/attendance-history' &&
        AppSession.instance.role != 'STUDENT') {
      return AppSession.instance.homePath;
    }

    // Phan 7: Ca 3 vai tro duoc vao trang canh bao.
    // Backend se loc du lieu theo vai tro.
    return null;
  },

  routes: [
    // Trang chao mung
    GoRoute(path: '/', builder: (context, state) => const WelcomePage()),

    // Dang nhap
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

    // Phan 6: Dang nhap khuon mat
    GoRoute(
      path: '/face-login',
      builder: (context, state) => const FaceLoginPage(),
    ),

    // Dang ky
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // Xac thuc OTP
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final args = state.extra;
        return args is OtpArguments
            ? OtpPage(arguments: args)
            : const LoginPage();
      },
    ),

    // Dashboard ADMIN
    GoRoute(
      path: '/admin',
      builder: (context, state) => const DashboardPage(role: 'ADMIN'),
    ),

    // Phan quyen
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UserRolesPage(),
    ),

    // Dashboard giang vien
    GoRoute(
      path: '/lecturer',
      builder: (context, state) => const DashboardPage(role: 'LECTURER'),
    ),

    // Dashboard sinh vien
    GoRoute(
      path: '/student',
      builder: (context, state) => const DashboardPage(role: 'STUDENT'),
    ),

    // Quan ly mon hoc
    GoRoute(
      path: '/courses',
      builder: (context, state) => const CatalogPage(type: 'courses'),
    ),

    // Quan ly phong hoc
    GoRoute(
      path: '/rooms',
      builder: (context, state) => const CatalogPage(type: 'rooms'),
    ),

    // Quan ly sinh vien
    GoRoute(
      path: '/students',
      builder: (context, state) => const StudentsPage(),
    ),

    // Danh sach lop hoc
    GoRoute(path: '/classes', builder: (context, state) => const ClassesPage()),

    // Lich su diem danh
    GoRoute(
      path: '/attendance-history',
      builder: (context, state) => const AttendanceHistoryPage(),
    ),

    // PHAN 7: THONG KE VA CANH BAO CHUYEN CAN
    GoRoute(
      path: '/attendance-risk',
      builder: (context, state) => const AttendanceRiskPage(),
    ),

    // Chi tiet lop hoc
    GoRoute(
      path: '/classes/:classId',
      builder: (context, state) =>
          ClassDetailPage(classId: state.pathParameters['classId']!),
    ),

    // Danh sach phien diem danh
    GoRoute(
      path: '/classes/:classId/sessions',
      builder: (context, state) =>
          SessionsPage(classId: state.pathParameters['classId']!),
    ),

    // Chi tiet diem danh
    GoRoute(
      path: '/classes/:classId/sessions/:sessionId',
      builder: (context, state) => AttendancePage(
        classId: state.pathParameters['classId']!,
        sessionId: state.pathParameters['sessionId']!,
      ),
    ),

    // Phan 5: Sinh vien quet QR + GPS
    GoRoute(
      path: '/qr/scan',
      builder: (context, state) => const QrGpsScanPage(),
    ),

    // Phan 5: Tao QR phien diem danh
    GoRoute(
      path: '/sessions/:sessionId/qr',
      builder: (context, state) =>
          SessionQrPage(sessionId: state.pathParameters['sessionId']!),
    ),

    // Don xin nghi hoc
    GoRoute(path: '/leaves', builder: (context, state) => const LeavesPage()),
  ],
);
