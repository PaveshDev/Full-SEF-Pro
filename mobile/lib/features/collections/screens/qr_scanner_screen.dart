import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/collection_model.dart';
import '../services/collections_api_service.dart';

class QrScannerScreen extends StatefulWidget {
  final String? expectedCollectionId;

  const QrScannerScreen({
    super.key,
    this.expectedCollectionId,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _collectionsService = CollectionsApiService();
  late MobileScannerController _controller;

  bool _isProcessing = false;
  HandoverPass? _scannedPass;
  String? _errorMessage;

  // Checklist state
  final Map<String, bool> _checklist = {};
  final TextEditingController _notesController = TextEditingController();
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _notesController.addListener(_onNotesChanged);
  }

  void _onNotesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _processPassCode(code);
  }

  Future<void> _processPassCode(String rawCode) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Extract recovery id or pass reference code
      String codeToQuery = rawCode.trim();
      if (codeToQuery.contains('verify-handover/')) {
        codeToQuery = codeToQuery.split('verify-handover/').last;
      }
      if (codeToQuery.contains('?')) {
        codeToQuery = codeToQuery.split('?').first;
      }
      if (codeToQuery.contains('#')) {
        codeToQuery = codeToQuery.split('#').first;
      }
      codeToQuery = codeToQuery.replaceAll('/', '').trim();

      final pass = await _collectionsService.getHandoverPass(codeToQuery);

      if (widget.expectedCollectionId != null && widget.expectedCollectionId!.isNotEmpty) {
        if (pass.collectionRequestId != null &&
            pass.collectionRequestId!.isNotEmpty &&
            pass.collectionRequestId!.toLowerCase() != widget.expectedCollectionId!.toLowerCase()) {
          setState(() {
            _errorMessage = 'Mismatched Pass! This pass is for "${pass.itemName}" (${pass.customerName}), but your active order ID is #${widget.expectedCollectionId}. Please scan the pass for the correct order.';
            _isProcessing = false;
          });
          return;
        }
      }

      setState(() {
        _scannedPass = pass;
        _isProcessing = false;
        // Pre-fill checklist
        _checklist.clear();
        _checklist['identity'] = false;
        for (int i = 0; i < pass.preparationSteps.length; i++) {
          _checklist['prep_$i'] = false;
        }
        for (int i = 0; i < pass.safetyNotes.length; i++) {
          _checklist['safety_$i'] = false;
        }
        _notesController.text = 'Verified pass ${pass.passReferenceCode} on-site at doorstep.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid or unrecognized Pass code: $e';
        _isProcessing = false;
      });
    }
  }

  void _showManualCodeDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Pass Code Manually'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. LPW-PASS-2ECABD0B or Recovery ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textController.text.isNotEmpty) {
                _processPassCode(textController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Search Pass', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDoorstepPickup() async {
    if (_scannedPass == null) return;
    final collectionId = _scannedPass!.collectionRequestId;
    if (collectionId == null || collectionId.isEmpty) {
      setState(() => _errorMessage = 'No collection schedule linked to this pass.');
      return;
    }

    final totalChecklist = 1 + _scannedPass!.preparationSteps.length + _scannedPass!.safetyNotes.length;
    final checkedCount = _checklist.values.where((v) => v == true).length;
    final allChecked = totalChecklist > 0 && checkedCount == totalChecklist;
    final notesFilled = _notesController.text.trim().isNotEmpty;

    if (!allChecked) {
      setState(() => _errorMessage = 'Please check off all $totalChecklist verification checklist items ($checkedCount/$totalChecklist completed).');
      return;
    }

    if (!notesFilled) {
      setState(() => _errorMessage = 'Please enter agent pickup remarks before confirming doorstep pickup.');
      return;
    }

    setState(() {
      _confirming = true;
      _errorMessage = null;
    });

    try {
      await _collectionsService.updateStatus(
        collectionId,
        status: 'Collected',
        note: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doorstep pickup confirmed! Status updated to Collected.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to confirm pickup: $e';
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify QR Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _showManualCodeDialog,
          ),
        ],
      ),
      body: _scannedPass == null
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcodeDetected,
                ),
                // Scanning overlay frame
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Point camera at Customer\'s Handover QR Pass',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _buildVerificationView(),
    );
  }

  Widget _buildVerificationView() {
    final pass = _scannedPass!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pass Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PASS VERIFIED',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pass.passReferenceCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pass.selectedRoute,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rose50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.rose500),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: AppColors.rose700, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],

          // Item & Customer Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pass.brand ?? ""} ${pass.model ?? ""} (${pass.itemName})'.trim(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${pass.customerName} • ${pass.customerDistrict ?? "District"}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  'Doorstep: ${pass.customerAddress ?? "On file"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Agent 2 On-Site Verification Checklist
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agent 2 On-Site Checklist',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_checklist.values.where((v) => v == true).length} of ${1 + pass.preparationSteps.length + pass.safetyNotes.length} items verified',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (_checklist.values.where((v) => v == true).length == (1 + pass.preparationSteps.length + pass.safetyNotes.length))
                          ? AppColors.primary
                          : AppColors.amber800,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    final total = 1 + pass.preparationSteps.length + pass.safetyNotes.length;
                    final currentChecked = _checklist.values.where((v) => v == true).length;
                    final nextVal = currentChecked != total;
                    _checklist['identity'] = nextVal;
                    for (int i = 0; i < pass.preparationSteps.length; i++) {
                      _checklist['prep_$i'] = nextVal;
                    }
                    for (int i = 0; i < pass.safetyNotes.length; i++) {
                      _checklist['safety_$i'] = nextVal;
                    }
                  });
                },
                icon: Icon(
                  (_checklist.values.where((v) => v == true).length == (1 + pass.preparationSteps.length + pass.safetyNotes.length))
                      ? Icons.clear_all
                      : Icons.done_all,
                  size: 16,
                ),
                label: Text(
                  (_checklist.values.where((v) => v == true).length == (1 + pass.preparationSteps.length + pass.safetyNotes.length))
                      ? 'Deselect All'
                      : 'Select All',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          CheckboxListTile(
            value: _checklist['identity'] ?? false,
            onChanged: (val) => setState(() => _checklist['identity'] = val ?? false),
            title: const Text('Physical Item Identity & Serial Verified', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Item condition matches "${pass.conditionDescription ?? "Good"}" description.', style: const TextStyle(fontSize: 11)),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
          ),

          for (int i = 0; i < pass.preparationSteps.length; i++)
            CheckboxListTile(
              value: _checklist['prep_$i'] ?? false,
              onChanged: (val) => setState(() => _checklist['prep_$i'] = val ?? false),
              title: Text('Preparation: ${pass.preparationSteps[i]}', style: const TextStyle(fontSize: 13)),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            ),

          for (int i = 0; i < pass.safetyNotes.length; i++)
            CheckboxListTile(
              value: _checklist['safety_$i'] ?? false,
              onChanged: (val) => setState(() => _checklist['safety_$i'] = val ?? false),
              title: Text('Safety Protocol: ${pass.safetyNotes[i]}', style: const TextStyle(fontSize: 13)),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 16),

          // Agent Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Agent Pickup Remarks *',
              hintText: 'e.g. Verified pass ${pass.passReferenceCode} on-site at doorstep.',
              errorText: _notesController.text.trim().isEmpty ? 'Remarks are required to confirm pickup' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),

          // Helper notice if not all completed
          Builder(
            builder: (context) {
              final totalChecklist = 1 + pass.preparationSteps.length + pass.safetyNotes.length;
              final checkedCount = _checklist.values.where((v) => v == true).length;
              final isAllChecked = totalChecklist > 0 && checkedCount == totalChecklist;
              final isNotesFilled = _notesController.text.trim().isNotEmpty;
              final canConfirm = !_confirming && isAllChecked && isNotesFilled;

              if (canConfirm) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.amber500.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.amber700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !isAllChecked && !isNotesFilled
                            ? 'Check all $totalChecklist inspection items and enter remarks to enable confirmation.'
                            : !isAllChecked
                                ? 'Check all remaining items ($checkedCount/$totalChecklist verified) to enable confirmation.'
                                : 'Please enter pickup remarks to enable confirmation.',
                        style: const TextStyle(fontSize: 12, color: AppColors.amber900),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Actions
          Builder(
            builder: (context) {
              final totalChecklist = 1 + pass.preparationSteps.length + pass.safetyNotes.length;
              final checkedCount = _checklist.values.where((v) => v == true).length;
              final isAllChecked = totalChecklist > 0 && checkedCount == totalChecklist;
              final isNotesFilled = _notesController.text.trim().isNotEmpty;
              final canConfirm = !_confirming && isAllChecked && isNotesFilled;

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _scannedPass = null;
                          _errorMessage = null;
                        });
                      },
                      child: const Text('Scan Another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: canConfirm ? _confirmDoorstepPickup : null,
                      icon: _confirming
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        _confirming ? 'Confirming...' : 'Confirm Doorstep Pickup',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
