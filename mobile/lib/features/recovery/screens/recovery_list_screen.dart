import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/recovery_model.dart';
import '../services/recovery_api_service.dart';

class RecoveryListScreen extends StatefulWidget {
  const RecoveryListScreen({super.key});

  @override
  State<RecoveryListScreen> createState() => _RecoveryListScreenState();
}

class _RecoveryListScreenState extends State<RecoveryListScreen> {
  final RecoveryApiService _api = RecoveryApiService();
  List<RecoveryRequestModel> _recoveries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecoveries();
  }

  Future<void> _loadRecoveries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _api.getRecoveries();
      if (mounted) {
        setState(() {
          _recoveries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load recovery requests.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Recovery Requests',
      child: RefreshIndicator(
        onRefresh: _loadRecoveries,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              const Text(
                'Recovery Plans & Approvals',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Track your recovery requests through preparation, approval, and partner matching',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.slateLight,
                ),
              ),
              const SizedBox(height: 24),

              // Error alert banner
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Content area
              if (_isLoading)
                _buildLoadingCard()
              else if (_recoveries.isEmpty)
                _buildEmptyCard()
              else
                _buildTableView(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading recovery plans...',
              style: TextStyle(color: AppColors.slateLight, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.repeat, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No recovery requests yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit an electronic waste item and select a recovery route to generate an AI preparation plan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.slateLight, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Go to My Items', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (!isDesktop) {
          // Responsive Card Layout for Mobile
          return Column(
            children: _recoveries.map((rec) => _buildMobileCard(context, rec)).toList(),
          );
        }

        // Full Table View Matching Web App
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Table Header
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Item',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Route',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Status',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Plan Summary',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Created',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Actions',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

              // Table Body Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recoveries.length,
                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final rec = _recoveries[index];
                  final createdStr = rec.createdAt != null
                      ? '${rec.createdAt!.month}/${rec.createdAt!.day}/${rec.createdAt!.year}'
                      : '-';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Item
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.item?.name.isNotEmpty == true ? rec.item!.name : 'Item',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.slateDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rec.item?.category?.name.isNotEmpty == true ? rec.item!.category!.name : (rec.item?.brand ?? 'Electronics'),
                                style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                              ),
                            ],
                          ),
                        ),

                        // Route
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              status: rec.selectedRoute,
                              type: 'route',
                            ),
                          ),
                        ),

                        // Status
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              status: rec.status,
                              type: 'status',
                            ),
                          ),
                        ),

                        // Plan Summary
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              rec.plan?.summary.isNotEmpty == true
                                  ? rec.plan!.summary
                                  : 'Plan pending generation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: rec.plan?.summary.isNotEmpty == true
                                    ? AppColors.slate
                                    : AppColors.slateLight,
                              ),
                            ),
                          ),
                        ),

                        // Created
                        Expanded(
                          flex: 2,
                          child: Text(
                            createdStr,
                            style: const TextStyle(fontSize: 13, color: AppColors.slateLight),
                          ),
                        ),

                        // Actions
                        SizedBox(
                          width: 110,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/recovery/${rec.id}'),
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: AppColors.slateDark),
                            label: const Text(
                              'View Plan',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slateDark),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileCard(BuildContext context, RecoveryRequestModel rec) {
    final createdStr = rec.createdAt != null
        ? '${rec.createdAt!.month}/${rec.createdAt!.day}/${rec.createdAt!.year}'
        : '-';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.item?.name.isNotEmpty == true ? rec.item!.name : 'Item',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slateDark),
                    ),
                    Text(
                      rec.item?.category?.name ?? 'Electronics',
                      style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: rec.status, type: 'status'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusBadge(status: rec.selectedRoute, type: 'route'),
              const Spacer(),
              Text(
                'Created $createdStr',
                style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
              ),
            ],
          ),
          if (rec.plan?.summary.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              rec.plan!.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/recovery/${rec.id}'),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.slateDark),
              label: const Text('View Plan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slateDark)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
