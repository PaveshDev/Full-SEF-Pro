import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
      final res = await _dio.get('/dashboard/admin');
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
    return AppShell(
      title: 'Admin Operations Dashboard',
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform Overview & Health',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Monitor multi-agent execution, human approvals, and physical logistics',
                          style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildStatCard(
                              title: 'Pending Recovery Approvals',
                              value: '${_stats?['pendingRecoveryApprovals'] ?? 0}',
                              icon: Icons.shield_outlined,
                              iconColor: AppColors.amber,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                            ),
                            _buildStatCard(
                              title: 'Awaiting Agent Assignment',
                              value: '${_stats?['collectionsAwaitingAssignment'] ?? 0}',
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.info,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                            ),
                            _buildStatCard(
                              title: 'Active Collections in Transit',
                              value: '${_stats?['activeCollections'] ?? 0}',
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.primary,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                            ),
                            _buildStatCard(
                              title: 'Active Certified Partners',
                              value: '${_stats?['activePartners'] ?? 0}',
                              icon: Icons.business_outlined,
                              iconColor: AppColors.primary,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                            ),
                            _buildStatCard(
                              title: 'Total Recoveries Completed',
                              value: '${_stats?['completedRecoveries'] ?? 0}',
                              icon: Icons.check_circle_outline,
                              iconColor: AppColors.success,
                              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Action Cards
                    const Text(
                      'Operational Control Hub',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildActionCard(
                      icon: Icons.shield_outlined,
                      title: 'Recovery Approvals Queue',
                      description:
                          'Review AI-generated preparation plans submitted by customers. Approve, request revisions, or reject before partner matching is unlocked.',
                      buttonText: 'Review Approvals Queue',
                      isPrimary: true,
                      onPressed: () => context.go('/admin/recovery'),
                    ),
                    const SizedBox(height: 12),

                    _buildActionCard(
                      icon: Icons.local_shipping_outlined,
                      title: 'Collection Agent Dispatch',
                      description:
                          'Assign collection agents to customer pickups based on Agent 4 proposals, confirm pickup windows, and verify final deliveries.',
                      buttonText: 'Manage Collections',
                      isPrimary: false,
                      onPressed: () => context.go('/admin/collections'),
                    ),
                    const SizedBox(height: 12),

                    _buildActionCard(
                      icon: Icons.memory_outlined,
                      title: 'AI Agent Workflow Auditing',
                      description:
                          'Inspect the end-to-end execution trail across Agent 1 (Item Assessment), Agent 2 (Recovery Planning), Agent 3 (Partner Matching), and Agent 4 (Collection Planning).',
                      buttonText: 'View Workflow History',
                      isPrimary: false,
                      onPressed: () => context.go('/admin/workflows'),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.business_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Accredited Partners & Agents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slateDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Configure registered recycling centers, charitable foundations, and field collection agent personnel.',
                            style: TextStyle(fontSize: 13, color: AppColors.slateLight, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => context.go('/admin/partners'),
                                icon: const Icon(Icons.business_outlined, size: 16),
                                label: const Text('Partners'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => context.go('/admin/collection-agents'),
                                icon: const Icon(Icons.group_outlined, size: 16),
                                label: const Text('Agents'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Container(
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
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: AppColors.slateLight, height: 1.4),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: isPrimary
                ? ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                    label: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
