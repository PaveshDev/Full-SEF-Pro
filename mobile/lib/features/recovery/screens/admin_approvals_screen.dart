import 'package:flutter/material.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/recovery_model.dart';
import '../services/recovery_api_service.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final RecoveryApiService _api = RecoveryApiService();
  List<RecoveryRequestModel> _pendingPlans = [];
  RecoveryRequestModel? _selectedRecovery;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _decision = 'Approved';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _customHandlingController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _customHandlingController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.getPendingApprovals();
      if (mounted) setState(() => _pendingPlans = list);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load pending recovery plans: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openReviewModal(RecoveryRequestModel recovery) {
    setState(() {
      _selectedRecovery = recovery;
      _decision = 'Approved';
      _reasonController.clear();
      _customHandlingController.text = recovery.plan?.adminHandlingInstructions ?? '';
      _errorMessage = null;
    });
  }

  void _closeReviewModal() {
    setState(() {
      _selectedRecovery = null;
      _reasonController.clear();
      _customHandlingController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submitDecision() async {
    final recovery = _selectedRecovery;
    if (recovery == null) return;

    if ((_decision == 'Rejected' || _decision == 'RevisionRequested') &&
        _reasonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'A reason is required when rejecting or requesting revisions.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _api.submitDecision(
        recovery.id,
        decision: _decision,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        customHandlingInstructions: _customHandlingController.text.trim().isNotEmpty ? _customHandlingController.text.trim() : null,
      );

      if (mounted) {
        final decisionText = _decision == 'Approved'
            ? 'approved'
            : (_decision == 'RevisionRequested' ? 'revision requested' : 'rejected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovery plan $decisionText successfully!')),
        );
        _closeReviewModal();
        await _loadApprovals();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to submit decision: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return AppShell(
      title: 'Human Admin Review Queue',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Refresh Queue',
        onPressed: _loadApprovals,
      ),
      child: RefreshIndicator(
        onRefresh: _loadApprovals,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Human Admin Review Queue',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review AI-generated preparation plans before items proceed to certified partner matching.',
                style: TextStyle(fontSize: 13, color: AppColors.slateLight),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.rose50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.rose500.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.rose500, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.rose700, fontSize: 13))),
                    ],
                  ),
                ),
              ],

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_pendingPlans.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
                        SizedBox(height: 16),
                        Text(
                          'No Recovery Plans Pending Review',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'All submitted recovery preparation plans have been evaluated.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slateLight, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                isWide && _selectedRecovery != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: _buildQueueList()),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _buildReviewPanel(_selectedRecovery!)),
                        ],
                      )
                    : Column(
                        children: [
                          if (_selectedRecovery != null) ...[
                            _buildReviewPanel(_selectedRecovery!),
                            const SizedBox(height: 20),
                          ],
                          _buildQueueList(),
                        ],
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final rec in _pendingPlans) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: _selectedRecovery?.id == rec.id ? AppColors.primary : AppColors.border,
                width: _selectedRecovery?.id == rec.id ? 2 : 1,
              ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.item?.name ?? 'Recovery Item',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.slateDark),
                            ),
                            if (rec.item?.category?.name != null)
                              Text(
                                rec.item!.category!.name,
                                style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              rec.selectedRoute,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(label: rec.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (rec.plan?.summary != null && rec.plan!.summary.isNotEmpty) ...[
                    Text(
                      rec.plan!.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rec.createdAt != null
                            ? 'Submitted: ${rec.createdAt!.toLocal().toString().split(' ')[0]}'
                            : '',
                        style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openReviewModal(rec),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.white),
                        label: Text(
                          _selectedRecovery?.id == rec.id ? 'Reviewing' : 'Review Plan',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewPanel(RecoveryRequestModel rec) {
    final item = rec.item;
    final eco = item?.ecoAssessment;
    final plan = rec.plan;
    final checklist = plan?.checklist ?? [];
    final totalChecklist = checklist.length;
    final doneChecklist = checklist.where((c) => c.isCompleted).length;
    final isVerified = plan?.isPreparationVerified ?? false;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item?.name ?? 'Recovery Review',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.slateDark),
                      ),
                      Text(
                        'Category: ${item?.category?.name ?? "N/A"} • Brand: ${item?.brand ?? "N/A"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _closeReviewModal,
                  tooltip: 'Close Review Panel',
                ),
              ],
            ),
            const Divider(height: 20),

            // Customer Condition Report
            if (item?.conditionDescription != null && item!.conditionDescription!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer Condition Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.slateDark)),
                    const SizedBox(height: 4),
                    Text(item.conditionDescription!, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4)),
                  ],
                ),
              ),
            ],

            // Feature 1: Eco Hazard Audit
            if (eco != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: eco.isHarmfulToEnvironment ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: eco.isHarmfulToEnvironment ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              eco.isHarmfulToEnvironment ? Icons.warning_amber_rounded : Icons.eco_outlined,
                              color: eco.isHarmfulToEnvironment ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Feature 1 Eco-Hazard Audit (${eco.hazardLevel.toUpperCase()} HAZARD)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: eco.isHarmfulToEnvironment ? const Color(0xFF991B1B) : const Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          eco.isHarmfulToEnvironment
                              ? (item?.ecoHazardAcknowledged == true ? '✓ Acknowledged' : '⚠️ Unacknowledged')
                              : '✓ Safe Device',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: eco.isHarmfulToEnvironment ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      eco.environmentalAlert,
                      style: TextStyle(
                        fontSize: 12,
                        color: eco.isHarmfulToEnvironment ? const Color(0xFF7F1D1D) : const Color(0xFF166534),
                        height: 1.4,
                      ),
                    ),
                    if (eco.detectedHazards.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: eco.detectedHazards.map((h) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text('⚠️ $h', style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Feature 2: Pre-Collection Readiness Checklist
            if (checklist.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Feature 2 Preparation Checklist ($doneChecklist/$totalChecklist Done)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isVerified ? const Color(0xFF166534) : const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          isVerified ? '✓ 100% Verified' : 'Pending Completion',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...checklist.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Icon(
                                c.isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                size: 14,
                                color: c.isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.isCompleted ? const Color(0xFF15803D) : AppColors.slateLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // Agent 2 Plan Details
            if (plan != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agent 2 Plan Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.slateDark)),
                    const SizedBox(height: 4),
                    Text(plan.summary, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Suitability: ${plan.suitability}', style: const TextStyle(fontSize: 11, color: AppColors.slateLight, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text('Facility: ${plan.requiredPartnerType}', style: const TextStyle(fontSize: 11, color: AppColors.slateLight, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (plan.steps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Preparation Steps:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.slateDark)),
                      const SizedBox(height: 4),
                      ...plan.steps.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${(e.key + 1).toString().padLeft(2, '0')}. ', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                Expanded(child: Text(e.value.stepText, style: const TextStyle(fontSize: 11, color: AppColors.slate))),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],

            // Confirmed Recovery Route
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confirmed Recovery Route:', style: TextStyle(fontSize: 12, color: AppColors.slateLight, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: rec.selectedRoute == 'Donate' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: rec.selectedRoute == 'Donate' ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      rec.selectedRoute,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rec.selectedRoute == 'Donate' ? const Color(0xFF166534) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Decision selector buttons (Approve, Revision, Reject)
            const Text('Admin Review Decision', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.slateDark)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _decision = 'Approved'),
                    icon: const Icon(Icons.check, size: 14, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _decision == 'Approved' ? AppColors.primary : AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _decision = 'RevisionRequested'),
                    icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                    label: const Text('Revision', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _decision == 'RevisionRequested' ? const Color(0xFFD97706) : AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _decision = 'Rejected'),
                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                    label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _decision == 'Rejected' ? AppColors.error : AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Feature 5: Special Handling Directives
            const Text('Special Handling & Courier Directives (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slateDark)),
            const SizedBox(height: 4),
            TextField(
              controller: _customHandlingController,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'e.g., Handle with insulated anti-static gloves; place in fire-resistant battery pouch.',
                hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 12),

            // Feedback / Reason
            Text(
              'Feedback / Reason ${(_decision == 'Rejected' || _decision == 'RevisionRequested') ? '*' : '(Optional)'}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slateDark),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Notes for the customer and audit history...',
                hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Decision button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDecision,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _decision == 'Rejected' ? AppColors.error : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Confirm Decision: $_decision',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
