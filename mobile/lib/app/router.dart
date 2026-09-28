import 'package:go_router/go_router.dart';

import '../shared/public/home_page.dart';
import '../shared/auth/login_screen.dart';
import '../shared/auth/register_screen.dart';
import '../shared/auth/profile_screen.dart';

import '../features/dashboard/screens/customer_dashboard_screen.dart';
import '../features/dashboard/screens/admin_dashboard_screen.dart';
import '../features/dashboard/screens/collection_agent_dashboard_screen.dart';
import '../features/partners/screens/partner_dashboard_screen.dart';

import '../features/items/routes.dart';
import '../features/recovery/routes.dart';
import '../features/partners/routes.dart';
import '../features/collections/routes.dart';
import '../features/workflows/routes.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const CustomerDashboardScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/agent',
      builder: (context, state) => const CollectionAgentDashboardScreen(),
    ),
    GoRoute(
      path: '/partner',
      builder: (context, state) => const PartnerDashboardScreen(),
    ),
    ...itemsRoutes,
    ...recoveryRoutes,
    ...partnersRoutes,
    ...collectionsRoutes,
    ...workflowsRoutes,
  ],
);
