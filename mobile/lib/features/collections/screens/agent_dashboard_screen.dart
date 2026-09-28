import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../models/collection_model.dart';
import '../services/collections_api_service.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  final _collectionsService = CollectionsApiService();

  List<CollectionRequest> _jobs = [];
  bool _loading = true;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final jobs = await _collectionsService.getAgentJobs();
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load assigned jobs: $e';
        _loading = false;
      });
    }
  }

  Future<void> _acceptJob(String id) async {
    try {
      setState(() {
        _error = null;
        _success = null;
      });
      await _collectionsService.acceptJob(id);
      setState(() {
        _success = 'Job accepted! Pickup scheduled. Duty status updated to Busy.';
      });
      _loadJobs();
    } catch (e) {
      setState(() => _error = 'Failed to accept job: $e');
    }
  }

  void _showRejectDialog(String id) {
    final reasonController = TextEditingController(text: 'Schedule conflict');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Collection Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify reason for declining. Order will be returned to Admin queue for AI re-dispatch.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _collectionsService.rejectJob(id, reason: reasonController.text);
                setState(() => _success = 'Job declined and returned for AI re-dispatch.');
                _loadJobs();
              } catch (e) {
                setState(() => _error = 'Failed to decline: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500),
            child: const Text('Decline Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handoverToPartner(CollectionRequest job) async {
    try {
      setState(() {
        _error = null;
        _success = null;
      });
      await _collectionsService.updateStatus(
        job.id,
        status: 'DeliveredToPartner',
        note: 'Delivered and handed over to ${job.partnerName}. Facility intake pending.',
      );
      setState(() {
        _success = 'Item handed over to ${job.partnerName}! Duty status updated to Available.';
      });
      _loadJobs();
    } catch (e) {
      setState(() => _error = 'Failed to update handover: $e');
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeJobs = _jobs.where((j) => j.status == 'Scheduled' || j.status == 'Collected').toList();
    final isBusy = activeJobs.isNotEmpty;

    return AppShell(
      title: 'Agent Collection Route',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.slateDark),
            tooltip: 'Reload',
            onPressed: _loadJobs,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            tooltip: 'Scan QR Pass',
            onPressed: () async {
              final result = await context.push('/agent/scan');
              if (result == true) {
                _loadJobs();
              }
            },
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duty Status Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isBusy ? AppColors.amber50 : AppColors.emerald50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isBusy ? AppColors.amber500 : AppColors.emerald500),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBusy ? Icons.schedule : Icons.check_circle_outline,
                            color: isBusy ? AppColors.amber700 : AppColors.emerald600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBusy ? 'Duty Status: Busy' : 'Duty Status: Available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isBusy ? AppColors.amber900 : AppColors.emerald900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isBusy
                                      ? '${activeJobs.length} active pickup in progress. Complete current handover to unlock new bookings.'
                                      : 'Ready to receive smart dispatch assignments from Admin & AI.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isBusy ? AppColors.amber800 : AppColors.emerald800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rose50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.rose500),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.rose700)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_success != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.emerald500),
                        ),
                        child: Text(_success!, style: const TextStyle(color: AppColors.emerald800)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Assigned Collection Jobs',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_jobs.length} total',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_jobs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Assigned Pickups',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Assigned customer collection jobs in your operational district will show up here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final job in _jobs) _buildJobCard(job),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildJobCard(CollectionRequest job) {
    final itemName = job.item?['name']?.toString() ?? 'E-Waste Item';
    final isNewAssigned = job.status == 'AgentAssigned';
    final isScheduled = job.status == 'Scheduled';
    final isCollected = job.status == 'Collected';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isScheduled || isCollected) ? AppColors.primary : AppColors.border,
          width: (isScheduled || isCollected) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(status: job.status),
              ],
            ),
            const SizedBox(height: 8),

            // Customer info with direct dialer
            Row(
              children: [
                const Icon(Icons.person, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  job.customerName ?? 'Customer',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                if (job.customerPhone != null && job.customerPhone!.isNotEmpty)
                  InkWell(
                    onTap: () => _callCustomer(job.customerPhone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.emerald500),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone, size: 12, color: AppColors.emerald700),
                          const SizedBox(width: 4),
                          Text(
                            job.customerPhone!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.emerald700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Doorstep Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${job.customerAddress ?? "On file"}, ${job.customerTown ?? ""} (${job.customerDistrict ?? ""})',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Designated Partner Facility
            Row(
              children: [
                const Icon(Icons.business_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Partner: ${job.partnerName}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // Actions based on status
            if (isNewAssigned) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(job.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rose500,
                        side: const BorderSide(color: AppColors.rose500),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _acceptJob(job.id),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Accept Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else if (isScheduled) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await context.push('/agent/scan?collectionId=${job.id}');
                    if (result == true) {
                      _loadJobs();
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                  label: const Text(
                    'Doorstep QR Scan & Inspection',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else if (isCollected) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handoverToPartner(job),
                  icon: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
                  label: Text(
                    'Handover to ${job.partnerName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate900,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.emerald600),
                  const SizedBox(width: 6),
                  Text(
                    'Status: ${job.status}',
                    style: const TextStyle(fontSize: 12, color: AppColors.emerald700, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
