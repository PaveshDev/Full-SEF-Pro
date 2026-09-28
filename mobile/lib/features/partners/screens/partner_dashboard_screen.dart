import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/config/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/auth/auth_provider.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../services/partners_api_service.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  final _partnersService = PartnersApiService();
  final _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  String? _error;
  String? _success;
  String _activeTab = 'incoming'; // 'incoming' or 'history'

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
      final data = await _partnersService.getPartnerCollections();
      setState(() {
        _collections = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load partner facility queue: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _incomingDeliveries {
    return _collections.where((c) {
      final s = c['status']?.toString().toLowerCase() ?? '';
      return s == 'deliveredtopartner';
    }).toList();
  }

  List<Map<String, dynamic>> get _completedIntakes {
    return _collections.where((c) {
      final s = c['status']?.toString().toLowerCase() ?? '';
      return s == 'completed' || s == 'partnerreceived';
    }).toList();
  }

  List<Map<String, dynamic>> get _flaggedIssues {
    return _completedIntakes.where((c) {
      return c['partnerReceivedConditionOk'] == false;
    }).toList();
  }

  void _openIntakeInspectionDialog(Map<String, dynamic> col) {
    Uint8List? photoBytes;
    String? photoFileName;
    bool conditionOk = true;
    final feedbackController = TextEditingController();
    bool submitting = false;
    String? dialogError;

    final item = col['item'] as Map<String, dynamic>?;
    final itemName = item?['name']?.toString() ?? 'E-Waste Item';
    final route = item?['selectedRecoveryRoute']?.toString() ?? 'Recycle';
    final customerName = col['customerName']?.toString() ?? 'Customer';
    final customerAddress = col['customerAddress']?.toString() ??
        col['customerDistrict']?.toString() ??
        '';
    final agentName = col['assignedAgentName']?.toString() ?? 'Collection Agent';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Facility Item Intake & Receipt Confirmation',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Inspect the received package, take an unboxing photo, and record intake feedback.',
                                  style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: AppColors.slateLight),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.rose50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.rose700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(color: AppColors.rose700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Device Summary Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slateDark,
                                    ),
                                  ),
                                ),
                                StatusBadge(status: route, type: 'route'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Customer: $customerName${customerAddress.isNotEmpty ? " ($customerAddress)" : ""}',
                              style: const TextStyle(fontSize: 12, color: AppColors.slateDark),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Collection Agent: $agentName',
                              style: const TextStyle(fontSize: 12, color: AppColors.slateDark),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 1: Upload Intake Photo
                      const Text(
                        '1. Upload Intake Photo of Received Item *',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Capture or upload a clear photo of the unboxed device on your receiving dock for audit and condition verification.',
                        style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                      ),
                      const SizedBox(height: 10),

                      if (photoBytes != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.black12,
                                child: Image.memory(
                                  photoBytes!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    photoBytes = null;
                                    photoFileName = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(180),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Change Photo',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: () async {
                            final picked = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setModalState(() {
                                photoBytes = bytes;
                                photoFileName = picked.name;
                                dialogError = null;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 36, color: AppColors.primary),
                                SizedBox(height: 8),
                                Text(
                                  'Click to capture or upload received item photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'PNG, JPG, or WebP up to 10MB',
                                  style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Section 2: Physical Condition & Damage Inspection
                      const Text(
                        '2. Physical Condition & Damage Inspection',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => conditionOk = true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: conditionOk ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: conditionOk ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                    width: conditionOk ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: conditionOk ? const Color(0xFF10B981) : AppColors.slateLight,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Condition Matches',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: conditionOk ? const Color(0xFF10B981) : AppColors.slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'No transit damages; physical state matches reported description.',
                                      style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => conditionOk = false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: !conditionOk ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !conditionOk ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                                    width: !conditionOk ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: !conditionOk ? const Color(0xFFEF4444) : AppColors.slateLight,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Damages / Defects',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: !conditionOk ? const Color(0xFFEF4444) : AppColors.slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Cracks, missing components, or transit damage observed upon unboxing.',
                                      style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Remarks
                      const Text(
                        '3. Intake Feedback & Service Remarks',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: feedbackController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter notes on physical inspection, unboxing condition, serial verification, or defect assessment...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: submitting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.slateDark,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (photoBytes == null) {
                                      setModalState(() {
                                        dialogError = 'Please upload an intake verification photo before confirming receipt.';
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      submitting = true;
                                      dialogError = null;
                                    });

                                    try {
                                      final collectionId = col['id']?.toString() ?? '';
                                      await _partnersService.confirmReceipt(
                                        collectionId,
                                        photoBytes: photoBytes,
                                        photoFileName: photoFileName,
                                        feedback: feedbackController.text,
                                        conditionOk: conditionOk,
                                      );

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }

                                      if (mounted) {
                                        setState(() {
                                          _success = 'Intake confirmed for item: $itemName. Recovery lifecycle completed.';
                                        });
                                        _loadCollections();
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        dialogError = 'Failed to submit inspection: $e';
                                        submitting = false;
                                      });
                                    }
                                  },
                            icon: submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check, size: 18, color: Colors.white),
                            label: Text(
                              submitting ? 'Confirming Receipt...' : 'Confirm Received Item',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF166534),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final incoming = _incomingDeliveries;
    final completed = _completedIntakes;
    final flagged = _flaggedIssues;

    return AppShell(
      title: 'Partner Intake Dashboard',
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withAlpha(20),
                            const Color(0xFF3B82F6).withAlpha(12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.business, size: 28, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user?.name ?? "Partner Facility"} Intake Operations',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Signed in as: ${user?.email ?? "partner@loopworth.com"}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Top 3 Metric Cards (Matching Web App)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  label: 'Awaiting Intake',
                                  count: incoming.length,
                                  subtitle: 'Handed over at dock',
                                  color: const Color(0xFFF59E0B),
                                  icon: Icons.access_time_rounded,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildMetricCard(
                                  label: 'Confirmed Received',
                                  count: completed.length,
                                  subtitle: 'Verified & completed',
                                  color: const Color(0xFF10B981),
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildMetricCard(
                                  label: 'Defects / Issues Flagged',
                                  count: flagged.length,
                                  subtitle: 'Intake condition notices',
                                  color: const Color(0xFFEF4444),
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildMetricCard(
                                label: 'Awaiting Intake',
                                count: incoming.length,
                                subtitle: 'Handed over at dock',
                                color: const Color(0xFFF59E0B),
                                icon: Icons.access_time_rounded,
                              ),
                              const SizedBox(height: 10),
                              _buildMetricCard(
                                label: 'Confirmed Received',
                                count: completed.length,
                                subtitle: 'Verified & completed',
                                color: const Color(0xFF10B981),
                                icon: Icons.check_circle_outline_rounded,
                              ),
                              const SizedBox(height: 10),
                              _buildMetricCard(
                                label: 'Defects / Issues Flagged',
                                count: flagged.length,
                                subtitle: 'Intake condition notices',
                                color: const Color(0xFFEF4444),
                                icon: Icons.warning_amber_rounded,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 18),

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
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.emerald600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _success!,
                                style: const TextStyle(color: AppColors.emerald800, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tab Navigation (Matching Web App)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton(
                            id: 'incoming',
                            label: 'Incoming Deliveries (${incoming.length})',
                            icon: Icons.inventory_2_outlined,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            id: 'history',
                            label: 'Intake Archive & History (${completed.length})',
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Content
                    if (_activeTab == 'incoming')
                      _buildIncomingTab(incoming)
                    else
                      _buildHistoryTab(completed),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -16,
            top: -16,
            bottom: -16,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slateLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isActive = _activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.slateLight,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.slateLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingTab(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.slateLight),
            SizedBox(height: 12),
            Text(
              'No Pending Handovers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
            ),
            SizedBox(height: 6),
            Text(
              'All items delivered to your facility have been verified and processed. When a collection agent hands over an item, it will immediately appear here for your intake inspection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slateLight),
            ),
          ],
        ),
      );
    }

    return Column(
      children: incoming.map((col) => _buildIncomingCard(col)).toList(),
    );
  }

  Widget _buildIncomingCard(Map<String, dynamic> col) {
    final item = col['item'] as Map<String, dynamic>?;
    final itemName = item?['name']?.toString() ?? 'E-Waste Item';
    final route = item?['selectedRecoveryRoute']?.toString() ?? 'Recycle';
    final categoryName = item?['category']?['name']?.toString() ?? item?['brand']?.toString() ?? 'Electronics';
    final modelName = item?['model']?.toString() ?? 'N/A';
    final conditionDesc = item?['conditionDescription']?.toString() ?? '';

    // Image
    final images = (item?['images'] as List?) ?? [];
    String? imgUrl;
    if (images.isNotEmpty) {
      imgUrl = images[0]['imageUrl']?.toString() ?? images[0]['url']?.toString();
    }
    final resolvedImg = ApiConstants.resolveImageUrl(imgUrl);

    // Handover info
    final agentName = col['assignedAgentName']?.toString() ?? 'Vikram';
    final customerName = col['customerName']?.toString() ?? 'Customer';

    final history = (col['statusHistory'] as List?) ?? [];
    String handoverTime = 'Recently delivered';
    for (final h in history.reversed) {
      if (h is Map && h['status']?.toString().toLowerCase() == 'deliveredtopartner') {
        if (h['changedAt'] != null) {
          final dt = DateTime.tryParse(h['changedAt'].toString());
          if (dt != null) {
            handoverTime = DateFormat('M/d/yyyy, h:mm:ss a').format(dt.toLocal());
          }
        }
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
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
          // Top Row: Item info & Handover metadata
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final leftContent = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFF1F5F9),
                      child: resolvedImg.isNotEmpty
                          ? Image.network(
                              resolvedImg,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.slateLight),
                            )
                          : const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.slateLight),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              itemName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                            ),
                            StatusBadge(status: route, type: 'route'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Delivered at Receiving Dock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Category: $categoryName | Model: $modelName',
                          style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                        ),
                        if (conditionDesc.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Customer Reported Condition: ',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.slateDark),
                                  ),
                                  TextSpan(
                                    text: conditionDesc,
                                    style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );

              final rightContent = Container(
                width: isWide ? 220 : double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(text: 'Delivered by: ', style: TextStyle(fontSize: 12, color: AppColors.slateLight)),
                                TextSpan(
                                  text: agentName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppColors.slateLight),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Customer: $customerName',
                            style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.slateLight),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            handoverTime,
                            style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftContent),
                    const SizedBox(width: 16),
                    rightContent,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftContent,
                    const SizedBox(height: 12),
                    rightContent,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Bottom Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Inspect the item, unbox package, take intake photo, and confirm receipt below.',
                  style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openIntakeInspectionDialog(col),
                icon: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
                label: const Text(
                  'Inspect & Confirm Receipt',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF166534),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(List<Map<String, dynamic>> completed) {
    if (completed.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No completed intakes in the archive yet.',
          style: TextStyle(fontSize: 13, color: AppColors.slateLight),
        ),
      );
    }

    return Column(
      children: completed.map((col) {
        final item = col['item'] as Map<String, dynamic>?;
        final itemName = item?['name']?.toString() ?? 'Device';
        final brand = item?['brand']?.toString() ?? '';
        final model = item?['model']?.toString() ?? '';
        final conditionOk = col['partnerReceivedConditionOk'] == true;
        final feedback = col['partnerFeedback']?.toString() ?? '';
        final agentName = col['assignedAgentName']?.toString() ?? 'Agent';
        final emailSent = col['deliveryEmailSent'] == true;

        final photoUrl = col['partnerPhotoUrl']?.toString();
        final resolvedPhoto = ApiConstants.resolveImageUrl(photoUrl);

        String confirmedTime = '';
        if (col['partnerConfirmedAt'] != null) {
          final dt = DateTime.tryParse(col['partnerConfirmedAt'].toString());
          if (dt != null) {
            confirmedTime = DateFormat('M/d/yyyy, h:mm a').format(dt.toLocal());
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail
              if (resolvedPhoto.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFFF1F5F9),
                    child: Image.network(
                      resolvedPhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.slateLight),
                    ),
                  ),
                )
              else
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.slateLight),
                ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: conditionOk ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                conditionOk ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                size: 12,
                                color: conditionOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                conditionOk ? 'Condition Matches' : 'Defects Flagged',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: conditionOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (brand.isNotEmpty || model.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$brand $model'.trim(),
                        style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                      ),
                    ],
                    if (feedback.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Remarks: $feedback',
                        style: const TextStyle(fontSize: 12, color: AppColors.slateDark, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text('Delivered by: $agentName', style: const TextStyle(fontSize: 11, color: AppColors.slateLight)),
                        if (confirmedTime.isNotEmpty)
                          Text('Confirmed: $confirmedTime', style: const TextStyle(fontSize: 11, color: AppColors.slateLight)),
                        if (emailSent)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mail_outline, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Receipt email sent (Brevo)', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
