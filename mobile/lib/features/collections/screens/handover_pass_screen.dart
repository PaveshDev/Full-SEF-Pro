import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../models/collection_model.dart';
import '../services/collections_api_service.dart';

class HandoverPassScreen extends StatefulWidget {
  final String recoveryId;

  const HandoverPassScreen({
    super.key,
    required this.recoveryId,
  });

  @override
  State<HandoverPassScreen> createState() => _HandoverPassScreenState();
}

class _HandoverPassScreenState extends State<HandoverPassScreen> {
  final _collectionsService = CollectionsApiService();

  HandoverPass? _pass;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPass();
  }

  Future<void> _loadPass() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pass = await _collectionsService.getHandoverPass(widget.recoveryId);
      setState(() {
        _pass = pass;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load handover pass: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppShell(
        title: 'Digital Handover Pass',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _pass == null) {
      return AppShell(
        title: 'Digital Handover Pass',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Pass not found.', style: const TextStyle(color: AppColors.rose500)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadPass, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    final pass = _pass!;

    return AppShell(
      title: 'Digital Handover Pass',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Reload',
        onPressed: _loadPass,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Column(
                    children: [
                      // Digital Pass Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Pass Header
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: AppColors.slate900,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Doorstep Handover Pass',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                          ),
                                          Text(
                                            'Certified E-Waste Chain of Custody',
                                            style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  StatusBadge(label: pass.status),
                                ],
                              ),
                            ),

                            // QR Section
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.border, width: 2),
                                    ),
                                    child: QrImageView(
                                      data: pass.passReferenceCode,
                                      version: QrVersions.auto,
                                      size: 180,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: AppColors.slateDark,
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: AppColors.slateDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    pass.passReferenceCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      letterSpacing: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Present this QR code to the collection agent during physical item handover',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(height: 1, color: AppColors.border),

                            // Item & Partner Details
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow('Item Name', pass.itemName),
                                  const SizedBox(height: 10),
                                  _infoRow('Item Category', pass.categoryName),
                                  const SizedBox(height: 10),
                                  _infoRow('Assigned Partner', pass.partnerName ?? 'Pending Assignment'),
                                  const SizedBox(height: 10),
                                  _infoRow('Pickup Address', pass.customerAddress ?? 'Doorstep Pickup Address'),
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    'Pickup Window',
                                    pass.scheduledPickupDate != null
                                        ? '${DateFormat("MMM dd, yyyy").format(pass.scheduledPickupDate!)} (${pass.scheduledStartTime ?? ""} - ${pass.scheduledEndTime ?? ""})'
                                        : 'Confirmed by Dispatch',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/items'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back to Items'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.go('/collections'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('View All Collections', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark),
          ),
        ),
      ],
    );
  }
}
