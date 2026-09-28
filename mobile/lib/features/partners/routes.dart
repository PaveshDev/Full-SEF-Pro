import 'package:go_router/go_router.dart';
import 'screens/customer_partner_matching_screen.dart';
import 'screens/partners_directory_screen.dart';
import 'screens/partner_dashboard_screen.dart';
import 'screens/admin_partners_screen.dart';

final List<RouteBase> partnersRoutes = <RouteBase>[
  GoRoute(
    path: '/matching-partners',
    builder: (context, state) => CustomerPartnerMatchingScreen(
      recoveryId: state.uri.queryParameters['recoveryId'] ?? '',
    ),
  ),
  GoRoute(
    path: '/matching-partners/:id',
    builder: (context, state) => CustomerPartnerMatchingScreen(
      recoveryId: state.pathParameters['id']!,
    ),
  ),
  GoRoute(
    path: '/recovery/:id/partners',
    builder: (context, state) => CustomerPartnerMatchingScreen(
      recoveryId: state.pathParameters['id']!,
    ),
  ),
  GoRoute(
    path: '/partners',
    builder: (context, state) => const PartnersDirectoryScreen(),
  ),
  GoRoute(
    path: '/partner',
    builder: (context, state) => const PartnerDashboardScreen(),
  ),
  GoRoute(
    path: '/partner/dashboard',
    builder: (context, state) => const PartnerDashboardScreen(),
  ),
  GoRoute(
    path: '/admin/partners',
    builder: (context, state) => const AdminPartnersScreen(),
  ),
];
