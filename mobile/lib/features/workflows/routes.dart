import 'package:go_router/go_router.dart';
import 'screens/ai_workflow_history_screen.dart';

final List<RouteBase> workflowsRoutes = <RouteBase>[
  GoRoute(
    path: '/admin/workflows',
    builder: (context, state) => const AIWorkflowHistoryScreen(),
  ),
];
