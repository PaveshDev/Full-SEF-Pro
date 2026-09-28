import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../shared/auth/auth_provider.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String title;
  final Widget? action;

  const AppShell({
    super.key,
    required this.child,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final role = user?.role ?? 'Customer';
    final currentRoute = GoRouterState.of(context).uri.path;

    final screenWidth = MediaQuery.of(context).size.width;
    final isFullSidebar = screenWidth >= 768;

    final fullSidebarWidget = _buildFullSidebar(context, auth, user, role, currentRoute);
    final compactRailWidget = _buildCompactSidebarRail(context, auth, user, role, currentRoute);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: !isFullSidebar
          ? Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(child: fullSidebarWidget),
            )
          : null,
      body: Row(
        children: [
          // STABLE SIDE NAVIGATION BAR
          if (isFullSidebar)
            SizedBox(
              width: 250,
              child: fullSidebarWidget,
            )
          else
            SizedBox(
              width: 64,
              child: SafeArea(
                right: false,
                child: compactRailWidget,
              ),
            ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),

          // CONTENT SECTION
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, title, action, isFullSidebar: isFullSidebar),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String title, Widget? action, {required bool isFullSidebar}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (!isFullSidebar) ...[
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: AppColors.slateDark, size: 22),
                      tooltip: 'Expand Menu',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }

  // COMPACT STABLE SIDE NAVIGATION BAR (For mobile portrait & compact screens)
  Widget _buildCompactSidebarRail(
    BuildContext context,
    AuthProvider auth,
    UserModel? user,
    String role,
    String currentRoute,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Top Brand Repeat Icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Builder(
              builder: (ctx) => Tooltip(
                message: 'LoopWorth (Tap to expand menu)',
                child: InkWell(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.repeat, color: AppColors.primary, size: 24),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Stable Icon Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (role == 'Customer') ...[
                  _railItem(context, Icons.dashboard_outlined, 'Dashboard', '/dashboard', currentRoute),
                  _railItem(context, Icons.inventory_2_outlined, 'My Items', '/items', currentRoute),
                  _railItem(context, Icons.alt_route, 'Recovery Requests', '/recovery', currentRoute),
                  _railItem(context, Icons.handshake_outlined, 'Partner Matching', '/matching-partners', currentRoute),
                  _railItem(context, Icons.local_shipping_outlined, 'Collections', '/collections', currentRoute),
                  _railItem(context, Icons.person_outline, 'My Profile', '/profile', currentRoute),
                ] else if (role == 'Admin') ...[
                  _railItem(context, Icons.dashboard_outlined, 'Admin Dashboard', '/admin', currentRoute),
                  _railItem(context, Icons.shield_outlined, 'Recovery Approvals', '/admin/recovery', currentRoute),
                  _railItem(context, Icons.business_outlined, 'Partners', '/admin/partners', currentRoute),
                  _railItem(context, Icons.local_shipping_outlined, 'Collections', '/admin/collections', currentRoute),
                  _railItem(context, Icons.group_outlined, 'Collection Agents', '/admin/collection-agents', currentRoute),
                  _railItem(context, Icons.memory_outlined, 'AI Workflows', '/admin/workflows', currentRoute),
                ] else if (role == 'CollectionAgent') ...[
                  _railItem(context, Icons.dashboard_outlined, 'Agent Dashboard', '/agent', currentRoute),
                  _railItem(context, Icons.route_outlined, 'Assigned Pickups', '/agent/jobs', currentRoute),
                ] else if (role == 'Partner') ...[
                  _railItem(context, Icons.dashboard_outlined, 'Partner Dashboard', '/partner', currentRoute),
                  _railItem(context, Icons.assignment_turned_in_outlined, 'Facility Intake', '/partner', currentRoute),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),
          // User Avatar & Sign Out
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Tooltip(
                  message: '${user?.name ?? "Account"} (${user?.role ?? ""})',
                  child: InkWell(
                    onTap: () => context.go('/profile'),
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      backgroundColor: AppColors.primarySubtle,
                      radius: 16,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Tooltip(
                  message: 'Sign Out',
                  child: IconButton(
                    icon: const Icon(Icons.logout, size: 20, color: AppColors.slateLight),
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railItem(BuildContext context, IconData icon, String title, String route, String currentRoute) {
    final isActive = currentRoute == route || currentRoute.startsWith('$route/');

    return Tooltip(
      message: title,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(icon, color: isActive ? AppColors.primary : AppColors.slateLight, size: 22),
          onPressed: () {
            Navigator.of(context).maybePop();
            context.go(route);
          },
        ),
      ),
    );
  }

  // FULL STABLE SIDEBAR (For desktop, landscape & drawer)
  Widget _buildFullSidebar(
    BuildContext context,
    AuthProvider auth,
    UserModel? user,
    String role,
    String currentRoute,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.repeat, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LoopWorth',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Give Waste Another Worth',
                      style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Nav links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                if (role == 'Customer') ...[
                  _navTile(context, Icons.dashboard_outlined, 'Dashboard', '/dashboard', currentRoute),
                  _navTile(context, Icons.inventory_2_outlined, 'My Items', '/items', currentRoute),
                  _navTile(context, Icons.alt_route, 'Recovery Requests', '/recovery', currentRoute),
                  _navTile(context, Icons.handshake_outlined, 'Partner Matching', '/matching-partners', currentRoute),
                  _navTile(context, Icons.local_shipping_outlined, 'Collections', '/collections', currentRoute),
                  _navTile(context, Icons.person_outline, 'My Profile', '/profile', currentRoute),
                ] else if (role == 'Admin') ...[
                  _navTile(context, Icons.dashboard_outlined, 'Admin Dashboard', '/admin', currentRoute),
                  _navTile(context, Icons.shield_outlined, 'Recovery Approvals', '/admin/recovery', currentRoute),
                  _navTile(context, Icons.business_outlined, 'Partners', '/admin/partners', currentRoute),
                  _navTile(context, Icons.local_shipping_outlined, 'Collections', '/admin/collections', currentRoute),
                  _navTile(context, Icons.group_outlined, 'Collection Agents', '/admin/collection-agents', currentRoute),
                  _navTile(context, Icons.memory_outlined, 'AI Workflows', '/admin/workflows', currentRoute),
                ] else if (role == 'CollectionAgent') ...[
                  _navTile(context, Icons.dashboard_outlined, 'Agent Dashboard', '/agent', currentRoute),
                  _navTile(context, Icons.route_outlined, 'Assigned Pickups', '/agent/jobs', currentRoute),
                ] else if (role == 'Partner') ...[
                  _navTile(context, Icons.dashboard_outlined, 'Partner Dashboard', '/partner', currentRoute),
                  _navTile(context, Icons.assignment_turned_in_outlined, 'Facility Intake', '/partner', currentRoute),
                ],
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => context.go('/profile'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primarySubtle,
                          radius: 18,
                          child: Text(
                            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Account',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slateDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$role • Profile',
                                style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                    icon: const Icon(Icons.logout, size: 16, color: AppColors.slateLight),
                    label: const Text('Sign Out', style: TextStyle(color: AppColors.slateLight, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String title, String route, String currentRoute) {
    final isActive = currentRoute == route || currentRoute.startsWith('$route/');

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primarySubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: isActive ? AppColors.primary : AppColors.slateLight, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.slateDark,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        onTap: () {
          Navigator.of(context).maybePop();
          context.go(route);
        },
      ),
    );
  }
}
