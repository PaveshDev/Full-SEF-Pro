import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/auth/auth_provider.dart';

class CollectionAgentDashboardScreen extends StatefulWidget {
  const CollectionAgentDashboardScreen({super.key});

  @override
  State<CollectionAgentDashboardScreen> createState() => _CollectionAgentDashboardScreenState();
}

class _CollectionAgentDashboardScreenState extends State<CollectionAgentDashboardScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/dashboard/agent');
      if (mounted) {
        setState(() {
          _stats = res.data as Map<String, dynamic>?;
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
      title: 'Collection Agent Portal',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Refresh',
        onPressed: _loadStats,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${user?.name ?? "Agent"}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your field collection metrics and pickup assignments',
                          style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stat Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildStatCard(
                              title: 'Pending Assigned Pickups',
                              value: '${_stats?['assignedJobs'] ?? 0}',
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.primary,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                            ),
                            _buildStatCard(
                              title: 'Scheduled For Today',
                              value: '${_stats?['todaysJobs'] ?? 0}',
                              icon: Icons.calendar_today_outlined,
                              iconColor: AppColors.amber,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                            ),
                            _buildStatCard(
                              title: 'Completed Deliveries',
                              value: '${_stats?['completedJobs'] ?? 0}',
                              icon: Icons.check_circle_outline,
                              iconColor: AppColors.success,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Active Jobs Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.route_outlined, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Active Pickup Jobs',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slateDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'View your dispatch route, contact details, item categories, and update delivery milestones in real-time.',
                            style: TextStyle(fontSize: 13, color: AppColors.slateLight, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => context.go('/agent/jobs'),
                                icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                                label: const Text('View Assigned Pickups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/agent/scan'),
                                icon: const Icon(Icons.qr_code_scanner, size: 16),
                                label: const Text('Scan QR Pass', style: TextStyle(fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slateLight,
                  ),
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.slateDark,
            ),
          ),
        ],
      ),
    );
  }
}
