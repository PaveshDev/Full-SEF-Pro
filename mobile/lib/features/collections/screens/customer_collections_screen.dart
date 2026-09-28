import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../models/collection_model.dart';
import '../services/collections_api_service.dart';

class CustomerCollectionsScreen extends StatefulWidget {
  const CustomerCollectionsScreen({super.key});

  @override
  State<CustomerCollectionsScreen> createState() => _CustomerCollectionsScreenState();
}

class _CustomerCollectionsScreenState extends State<CustomerCollectionsScreen> {
  final _collectionsService = CollectionsApiService();

  List<CollectionRequest> _collections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final collections = await _collectionsService.getCustomerCollections();
      setState(() {
        _collections = collections;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load collections: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'My Collections & Pickups',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Reload',
        onPressed: _loadCollections,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCollections,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Doorstep Collections',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_collections.length} items',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_collections.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Collections Scheduled',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'After selecting an e-waste recovery route and partner, schedule your doorstep collection here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final col in _collections) _buildCollectionCard(col),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCollectionCard(CollectionRequest col) {
    final itemName = col.item?['name']?.toString() ?? 'E-Waste Item';
    final dateStr = col.scheduledPickupDate != null
        ? DateFormat('EEEE, MMM d, yyyy').format(col.scheduledPickupDate!)
        : col.preferredPickupDate != null
            ? DateFormat('EEEE, MMM d, yyyy').format(col.preferredPickupDate!)
            : 'Pending scheduling';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: StatusBadge(status: col.status),
                ),
              ],
            ),
            if (col.status.toLowerCase() == 'deliveredtopartner') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFF4338CA)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Item handed over to partner • Waiting for partner review and confirmation',
                        style: TextStyle(fontSize: 12, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(Icons.business_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Partner: ${col.partnerName}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
            if (col.assignedAgentName != null && col.assignedAgentName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Agent: ${col.assignedAgentName}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/collections/pass/${col.recoveryRequestId}');
                },
                icon: const Icon(Icons.qr_code, size: 16, color: Colors.white),
                label: const Text('View Handover QR Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
