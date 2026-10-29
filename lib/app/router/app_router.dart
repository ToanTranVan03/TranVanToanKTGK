import 'package:go_router/go_router.dart';
import '../../core/session/app_session.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/admin/presentation/pages/user_roles_page.dart';
import '../../features/dashboards/presentation/pages/dashboard_page.dart';
import '../../features/home/presentation/pages/welcome_page.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  refreshListenable: AppSession.instance,
  redirect: (context, state) {
    final path = state.uri.path;
    final protectedRoute = path == '/admin' || path == '/student' ||
        path == '/lecturer' || path.startsWith('/admin/');
    if (protectedRoute && !AppSession.instance.isAuthenticated) return '/login';
    if (protectedRoute && path.startsWith('/admin') && AppSession.instance.role != 'ADMIN') {
      return AppSession.instance.homePath;
    }
    if (protectedRoute && path == '/lecturer' && AppSession.instance.role != 'LECTURER') {
      return AppSession.instance.homePath;
    }
    if (protectedRoute && path == '/student' && AppSession.instance.role != 'STUDENT') {
      return AppSession.instance.homePath;
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
    GoRoute(path: '/otp', builder: (context, state) {
      final args = state.extra;
      return args is OtpArguments ? OtpPage(arguments: args) : const LoginPage();
    }),
    GoRoute(path: '/admin', builder: (context, state) => const DashboardPage(role: 'ADMIN')),
    GoRoute(path: '/admin/users', builder: (context, state) => const UserRolesPage()),
    GoRoute(path: '/lecturer', builder: (context, state) => const DashboardPage(role: 'LECTURER')),
    GoRoute(path: '/student', builder: (context, state) => const DashboardPage(role: 'STUDENT')),
  ],
);
