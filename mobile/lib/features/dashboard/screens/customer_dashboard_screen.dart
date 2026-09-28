import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/auth/auth_provider.dart';
import '../../../../shared/widgets/status_badge.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _stats;
  List<dynamic> _recentItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final statsRes = await _dio.get('/dashboard/customer');
      final itemsRes = await _dio.get('/items', queryParameters: {'pageSize': 5});

      if (mounted) {
        setState(() {
          _stats = statsRes.data is Map ? Map<String, dynamic>.from(statsRes.data) : null;
          final dynamic rawItems = itemsRes.data;
          _recentItems = rawItems is List
              ? rawItems
              : (rawItems is Map ? (rawItems['items'] as List? ?? []) : []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return AppShell(
      title: 'Dashboard',
      action: ElevatedButton.icon(
        onPressed: () => context.push('/items/submit'),
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Submit Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header welcome
                    Text(
                      'Welcome back, ${user?.name ?? "User"}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track your electronic waste recovery lifecycle at a glance',
                      style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                    ),
                    const SizedBox(height: 20),

                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Items',
                            '${_stats?['totalItems'] ?? 0}',
                            Icons.inventory_2_outlined,
                            AppColors.primary,
                            AppColors.primarySubtle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Pending Review',
                            '${_stats?['pendingRecovery'] ?? 0}',
                            Icons.repeat,
                            AppColors.warning,
                            AppColors.warningBg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Active Collections',
                            '${_stats?['activeCollections'] ?? 0}',
                            Icons.local_shipping_outlined,
                            AppColors.info,
                            AppColors.infoBg,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Completed',
                            '${_stats?['completedItems'] ?? 0}',
                            Icons.check_circle_outline,
                            AppColors.success,
                            AppColors.successBg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Registered Pickup Location Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Registered Pickup Location & Contact',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slateDark),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySubtle,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('Active', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Address: ${user?.address != null && user!.address.isNotEmpty ? "${user.address}, ${user.town}, ${user.district}" : "Not provided yet"}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                ),
                                if (user?.phone != null && user!.phone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Phone: ${user.phone}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Items',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                        ),
                        TextButton(
                          onPressed: () => context.go('/items'),
                          child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_recentItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.slateLight),
                            const SizedBox(height: 10),
                            const Text('No items submitted yet', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Submit your first e-waste item to start the AI recovery process.', style: TextStyle(fontSize: 12, color: AppColors.slateLight)),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () => context.push('/items/submit'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              child: const Text('Submit Waste Item', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final item in _recentItems)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.devices, color: AppColors.primary, size: 20),
                            ),
                            title: Text(item['name']?.toString() ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Category: ${item['categoryName'] ?? "E-Waste"}', style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                            trailing: StatusBadge(status: item['status']?.toString()),
                            onTap: () => context.push('/items/${item['id']}'),
                          ),
                        ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.slateLight, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.slateDark)),
        ],
      ),
    );
  }
}

