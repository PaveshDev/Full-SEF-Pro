import 'package:flutter/material.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';

class AdminCollectionsScreen extends StatefulWidget {
  const AdminCollectionsScreen({super.key});

  @override
  State<AdminCollectionsScreen> createState() => _AdminCollectionsScreenState();
}

class _AdminCollectionsScreenState extends State<AdminCollectionsScreen> {
  final _dio = ApiClient().dio;
  List<dynamic> _collections = [];
  bool _loading = true;
  String? _assigningId;
  String? _sendingEmailId;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/admin/collections');
      if (mounted) {
        setState(() {
          _collections = res.data as List;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load collections queue.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _assignAgent(String id, bool isReassign) async {
    setState(() {
      _assigningId = id;
      _error = null;
      _success = null;
    });
    try {
      final res = await _dio.post('/admin/collections/$id/assign-agent');
      final agentName = res.data['assignedAgentName'] ?? 'Agent';
      if (mounted) {
        setState(() {
          _success = isReassign
              ? 'Reassigned to collection agent ($agentName) via Agentic AI.'
              : 'Assigned to collection agent ($agentName) via Agentic AI.';
        });
        await _loadData();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Failed to dispatch agent with Agentic AI.';
        });
      }
    } finally {
      if (mounted) setState(() => _assigningId = null);
    }
  }

  Future<void> _sendDeliveryEmail(String id) async {
    setState(() {
      _sendingEmailId = id;
      _error = null;
      _success = null;
    });
    try {
      await _dio.post('/admin/collections/$id/send-delivery-email');
      if (mounted) {
        setState(() {
          _success = 'Delivery email notification successfully generated and dispatched via Brevo!';
        });
        await _loadData();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Failed to dispatch email via Brevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _sendingEmailId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Collections Logistics',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Refresh',
        onPressed: _loadData,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
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
                          'Collection Logistics & Milestones',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Review customer pickup requests, dispatch available agents with Agentic AI, and track handovers',
                          style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.roseLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.rose.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.rose, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 13))),
                          ],
                        ),
                      ),

                    if (_success != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.emerald.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_success!, style: const TextStyle(color: AppColors.emerald, fontSize: 13))),
                          ],
                        ),
                      ),

                    if (_collections.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.primary),
                            SizedBox(height: 14),
                            Text(
                              'No active collection requests',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _collections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final c = _collections[idx] as Map<String, dynamic>;
                          final id = c['id']?.toString() ?? '';
                          final item = c['item'] as Map<String, dynamic>?;
                          final itemName = item?['name'] ?? 'Item';
                          final partnerName = c['partnerName'] ?? 'Partner';
                          final status = c['status'] ?? 'Requested';
                          final assignedAgentName = c['assignedAgentName'];
                          final agentAssigned = c['assignedCollectionAgentId'] != null;
                          final pickupDate = c['scheduledPickupDate'] != null
                              ? DateTime.tryParse(c['scheduledPickupDate'])?.toLocal().toString().split(' ')[0]
                              : null;
                          final prefDate = c['preferredPickupDate'] != null
                              ? DateTime.tryParse(c['preferredPickupDate'])?.toLocal().toString().split(' ')[0]
                              : null;
                          final emailSent = c['deliveryEmailSent'] == true;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.slateDark,
                                              ),
                                            ),
                                            Text(
                                              'To: $partnerName',
                                              style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                            ),
                                            if (status.toString().toLowerCase() == 'deliveredtopartner') ...[
                                              const SizedBox(height: 3),
                                              const Row(
                                                children: [
                                                  Icon(Icons.hourglass_top_rounded, size: 13, color: Color(0xFF4338CA)),
                                                  SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Waiting for partner review and confirmation',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF4338CA),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: StatusBadge(status: status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin_outlined, size: 16, color: AppColors.slateLight),
                                      const SizedBox(width: 6),
                                      Text(
                                        assignedAgentName != null
                                            ? 'Agent: $assignedAgentName'
                                            : 'Agent: Unassigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: assignedAgentName != null ? FontWeight.w600 : FontWeight.normal,
                                          color: assignedAgentName != null ? AppColors.slateDark : AppColors.slateLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.slateLight),
                                      const SizedBox(width: 6),
                                      Text(
                                        pickupDate != null
                                            ? 'Scheduled: $pickupDate'
                                            : (prefDate != null ? 'Pref: $prefDate' : 'No date set'),
                                        style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                      ),
                                    ],
                                  ),
                                  if (emailSent) ...[
                                    const SizedBox(height: 6),
                                    const Row(
                                      children: [
                                        Icon(Icons.mail_outline, size: 16, color: AppColors.primary),
                                        SizedBox(width: 6),
                                        Text('Delivery email sent (Brevo)', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      if (status == 'Requested' || status == 'AgentAssigned')
                                        ElevatedButton.icon(
                                          onPressed: _assigningId == id
                                              ? null
                                              : () => _assignAgent(id, agentAssigned),
                                          icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                                          label: Text(
                                            _assigningId == id
                                                ? 'Dispatching...'
                                                : (agentAssigned ? 'Reassign (AI)' : 'Assign Agent (AI)'),
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      if (status == 'Completed')
                                        OutlinedButton.icon(
                                          onPressed: _sendingEmailId == id
                                              ? null
                                              : () => _sendDeliveryEmail(id),
                                          icon: const Icon(Icons.mail_outline, size: 14),
                                          label: Text(
                                            _sendingEmailId == id ? 'Sending...' : 'Resend Email (Brevo)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showDetailsModal(c),
                                        icon: const Icon(Icons.visibility_outlined, size: 14),
                                        label: const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showDetailsModal(Map<String, dynamic> c) {
    final history = (c['statusHistory'] as List?) ?? [];
    final item = c['item'] as Map<String, dynamic>?;
    final itemName = item?['name'] ?? 'Item';
    final status = c['status'] ?? '';
    final agentName = c['assignedAgentName'] ?? 'Unassigned';
    final partnerName = c['partnerName'] ?? 'Partner';
    final emailSent = c['deliveryEmailSent'] == true;
    final emailSub = c['deliveryEmailSubject'] ?? '';
    final emailSentAt = c['deliveryEmailSentAt'] != null
        ? DateTime.tryParse(c['deliveryEmailSentAt'])?.toLocal().toString().split('.')[0]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Collection Request Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slateDark,
                            ),
                          ),
                          Text('Item: $itemName', style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Status', style: TextStyle(fontSize: 11, color: AppColors.slateLight)),
                                    const SizedBox(height: 4),
                                    StatusBadge(status: status),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Assigned Agent', style: TextStyle(fontSize: 11, color: AppColors.slateLight)),
                                    const SizedBox(height: 4),
                                    Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slateDark)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Destination Partner: $partnerName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                        const SizedBox(height: 16),

                        // Timeline
                        const Text('Event Timeline & Milestones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                        const SizedBox(height: 8),
                        if (history.isEmpty)
                          const Text('No status events logged yet.', style: TextStyle(fontSize: 12, color: AppColors.slateLight))
                        else
                          ...history.map((h) {
                            final hMap = h as Map<String, dynamic>;
                            final hStatus = hMap['status'] ?? '';
                            final hNote = hMap['note'];
                            final hTime = hMap['changedAt'] != null
                                ? DateTime.tryParse(hMap['changedAt'])?.toLocal().toString().split('.')[0] ?? ''
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      StatusBadge(status: hStatus),
                                      Text(hTime, style: const TextStyle(fontSize: 11, color: AppColors.slateLight)),
                                    ],
                                  ),
                                  if (hNote != null && hNote.toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(hNote.toString(), style: const TextStyle(fontSize: 12, color: AppColors.slateDark)),
                                  ],
                                ],
                              ),
                            );
                          }),

                        if (status == 'Completed') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.mail_outline, size: 16, color: AppColors.primary),
                                        SizedBox(width: 6),
                                        Text('Customer Notification (Brevo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slateDark)),
                                      ],
                                    ),
                                    StatusBadge(status: emailSent ? 'Email Dispatched' : 'Pending'),
                                  ],
                                ),
                                if (emailSent) ...[
                                  const SizedBox(height: 6),
                                  Text('Subject: $emailSub', style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                                  if (emailSentAt != null)
                                    Text('Sent at: $emailSentAt', style: const TextStyle(fontSize: 11, color: AppColors.slateLight)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
