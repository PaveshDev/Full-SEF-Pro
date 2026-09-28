import 'package:go_router/go_router.dart';
import 'screens/items_list_screen.dart';
import 'screens/item_submit_screen.dart';
import 'screens/item_detail_screen.dart';

final List<RouteBase> itemsRoutes = <RouteBase>[
  GoRoute(
    path: '/items',
    builder: (context, state) => const ItemsListScreen(),
  ),
  GoRoute(
    path: '/items/submit',
    builder: (context, state) => const ItemSubmitScreen(),
  ),
  GoRoute(
    path: '/items/new',
    builder: (context, state) => const ItemSubmitScreen(),
  ),
  GoRoute(
    path: '/items/:id',
    builder: (context, state) => ItemDetailScreen(
      itemId: state.pathParameters['id']!,
    ),
  ),
];
