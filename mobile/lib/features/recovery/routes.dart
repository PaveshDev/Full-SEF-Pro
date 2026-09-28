import 'package:go_router/go_router.dart';
import 'screens/recovery_list_screen.dart';
import 'screens/recovery_route_screen.dart';
import 'screens/recovery_plan_screen.dart';
import 'screens/admin_approvals_screen.dart';
import '../collections/screens/handover_pass_screen.dart';

final List<RouteBase> recoveryRoutes = <RouteBase>[
  GoRoute(
    path: '/recovery',
    builder: (context, state) => const RecoveryListScreen(),
  ),
  GoRoute(
    path: '/recovery/select',
    builder: (context, state) => RecoveryRouteScreen(
      itemId: state.uri.queryParameters['itemId'] ?? '',
    ),
  ),
  GoRoute(
    path: '/recovery/:id',
    builder: (context, state) => RecoveryPlanScreen(
      recoveryId: state.pathParameters['id']!,
    ),
  ),
  GoRoute(
    path: '/verify-handover/:id',
    builder: (context, state) => HandoverPassScreen(
      recoveryId: state.pathParameters['id']!,
    ),
  ),
  GoRoute(
    path: '/admin/recovery',
    builder: (context, state) => const AdminApprovalsScreen(),
  ),
  GoRoute(
    path: '/admin/approvals',
    builder: (context, state) => const AdminApprovalsScreen(),
  ),
];

