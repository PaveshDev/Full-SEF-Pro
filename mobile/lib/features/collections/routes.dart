import 'package:go_router/go_router.dart';
import 'screens/schedule_pickup_screen.dart';
import 'screens/handover_pass_screen.dart';
import 'screens/agent_dashboard_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/customer_collections_screen.dart';
import 'screens/admin_collections_screen.dart';
import 'screens/admin_collection_agents_screen.dart';

final List<RouteBase> collectionsRoutes = <RouteBase>[
  GoRoute(
    path: '/collections',
    builder: (context, state) => const CustomerCollectionsScreen(),
  ),
  GoRoute(
    path: '/recovery/:id/schedule',
    builder: (context, state) => SchedulePickupScreen(
      recoveryId: state.pathParameters['id']!,
    ),
  ),
  GoRoute(
    path: '/collections/pass/:id',
    builder: (context, state) => HandoverPassScreen(
      recoveryId: state.pathParameters['id']!,
    ),
  ),
  GoRoute(
    path: '/agent/jobs',
    builder: (context, state) => const AgentDashboardScreen(),
  ),
  GoRoute(
    path: '/agent/collections',
    builder: (context, state) => const AgentDashboardScreen(),
  ),
  GoRoute(
    path: '/agent/scan',
    builder: (context, state) => QrScannerScreen(
      expectedCollectionId: state.uri.queryParameters['collectionId'],
    ),
  ),
  GoRoute(
    path: '/admin/collections',
    builder: (context, state) => const AdminCollectionsScreen(),
  ),
  GoRoute(
    path: '/admin/collection-agents',
    builder: (context, state) => const AdminCollectionAgentsScreen(),
  ),
];
