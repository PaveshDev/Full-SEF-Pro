import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/app_shell.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/item_model.dart';
import '../services/items_api_service.dart';
import '../../recovery/services/recovery_api_service.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final ItemsApiService _api = ItemsApiService();
  ItemModel? _item;
  bool _isLoading = true;
  bool _isAssessing = false;
  bool _isAcknowledgingEco = false;
  bool _isSwitchingRoute = false;
  bool _isSelectingRoute = false;
  bool _isStartingRecovery = false;
  String? _statusMessage;
  String? _errorMessage;
  Map<String, dynamic>? _categoryMismatch;
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getItemById(widget.itemId);
      if (mounted) {
        setState(() {
          _item = data;
          if (data.assessment != null) {
            _categoryMismatch = null;
          }
        });
        // Auto-run eco assessment if missing
        if (data.ecoAssessment == null) {
          try {
            await _api.triggerEcoAssessment(data.id);
            final updated = await _api.getItemById(widget.itemId);
            if (mounted) setState(() => _item = updated);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load item: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcknowledgeEco() async {
    setState(() {
      _isAcknowledgingEco = true;
      _errorMessage = null;
    });
    try {
      await _api.acknowledgeEcoHazard(widget.itemId);
      setState(() => _statusMessage = 'Environmental precautions acknowledged. You may now run advisory assessment.');
      await _loadItem();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to acknowledge precautions: $e');
    } finally {
      if (mounted) setState(() => _isAcknowledgingEco = false);
    }
  }

  Future<void> _handleSwitchToRecycle() async {
    setState(() {
      _isSwitchingRoute = true;
      _errorMessage = null;
    });
    try {
      await _api.switchToRecycle(widget.itemId);
      setState(() => _statusMessage = 'Route successfully switched to Recycle.');
      await _loadItem();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to switch route: $e');
    } finally {
      if (mounted) setState(() => _isSwitchingRoute = false);
    }
  }

  Future<void> _uploadMorePhotos() async {
    final picker = ImagePicker();
    try {
      final pickedList = await picker.pickMultiImage();
      if (pickedList.isNotEmpty) {
        for (final file in pickedList) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            await _api.uploadPhotoBytes(widget.itemId, bytes, file.name);
          }
        }
      } else {
        final single = await picker.pickImage(source: ImageSource.gallery);
        if (single != null) {
          final bytes = await single.readAsBytes();
          if (bytes.isNotEmpty) {
            await _api.uploadPhotoBytes(widget.itemId, bytes, single.name);
          }
        }
      }
      if (mounted) {
        setState(() => _statusMessage = 'Photo(s) uploaded successfully.');
        await _loadItem();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to upload photo: $e');
      }
    }
  }

  Future<void> _triggerAssessment() async {
    final status = _item?.status ?? '';
    const assessableStatuses = ['Draft', 'Submitted', 'AssessmentPending'];
    if (!assessableStatuses.contains(status)) {
      setState(() => _errorMessage = 'Assessment cannot be run for an item in "$status" status.');
      return;
    }

    setState(() {
      _isAssessing = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      if (status == 'Draft') {
        await _api.submitItem(widget.itemId);
      }
      await _api.triggerAiAssessment(widget.itemId);
      setState(() => _statusMessage = 'Agent 1 Advisory Assessment completed.');
      await _loadItem();
      if (_item != null && _item!.assessment != null) {
        final isDonateBlocked = _item!.ecoAssessment?.canBeDonated == false;
        final recRoute = _item!.assessment!.recommendedRecoveryRoute;
        final autoRoute = (isDonateBlocked || recRoute == 'Recycle') ? 'Recycle' : (recRoute.isNotEmpty ? recRoute : 'Recycle');
        try {
          await _api.selectRoute(widget.itemId, autoRoute);
          await _loadItem();
        } catch (_) {}
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      final bodyMap = body is Map ? body : {};
      final errorStr = (bodyMap['error'] ?? bodyMap['mismatchReason'] ?? e.message ?? '').toString();
      final bool isMismatch = code == 422 ||
          bodyMap['isCategoryMismatch'] == true ||
          errorStr.toLowerCase().contains('category mismatch') ||
          errorStr.toLowerCase().contains('description inconsistency') ||
          errorStr.toLowerCase().contains('description mismatch') ||
          errorStr.toLowerCase().contains('inconsistency') ||
          errorStr.toLowerCase().contains('please edit the item');

      if (isMismatch) {
        final reason = bodyMap['mismatchReason'] ?? bodyMap['error'] ?? errorStr;
        String type = (bodyMap['inconsistencyType'] ?? '').toString();
        if (type.isEmpty) {
          if (errorStr.toLowerCase().contains('description')) {
            type = 'DescriptionMismatch';
          } else {
            type = 'CategoryMismatch';
          }
        }
        String? detectedCat = bodyMap['detectedCategory']?.toString();
        if (detectedCat == null || detectedCat.isEmpty) {
          final match = RegExp(r"select the '([^']+)' category", caseSensitive: false).firstMatch(reason.toString());
          if (match != null) {
            detectedCat = match.group(1);
          }
        }

        setState(() {
          _categoryMismatch = {
            'reason': reason,
            'detectedCategory': detectedCat,
            'inconsistencyType': type,
          };
          _errorMessage = null;
        });
      } else if (code == 400) {
        final msg = body is Map ? (body['error'] ?? 'Assessment blocked.') : 'Assessment failed.';
        setState(() => _errorMessage = msg.toString());
      } else {
        setState(() => _errorMessage = 'Assessment error: ${e.message}');
      }
      await _loadItem(); // reload so status reflects any revert
    } catch (e) {
      setState(() => _errorMessage = 'Assessment error: $e');
    } finally {
      if (mounted) setState(() => _isAssessing = false);
    }
  }

  Future<void> _handleSelectRoute(String route) async {
    setState(() {
      _isSelectingRoute = true;
      _errorMessage = null;
    });
    try {
      await _api.selectRoute(widget.itemId, route);
      await _loadItem();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select route: $e');
    } finally {
      if (mounted) setState(() => _isSelectingRoute = false);
    }
  }

  Future<void> _handleCreateRecovery() async {
    setState(() {
      _isStartingRecovery = true;
      _errorMessage = null;
    });
    try {
      final item = _item;
      if (item != null && item.selectedRecoveryRoute == null) {
        final isDonateBlocked = item.ecoAssessment?.canBeDonated == false;
        final recRoute = item.assessment?.recommendedRecoveryRoute ?? 'Recycle';
        final defRoute = (isDonateBlocked || recRoute == 'Recycle') ? 'Recycle' : 'Donate';
        await _api.selectRoute(widget.itemId, defRoute);
        await _loadItem();
      }
      final recoveryApi = RecoveryApiService();
      final recovery = await recoveryApi.createRecoveryRequest(widget.itemId);
      if (recovery.plan == null) {
        try {
          await recoveryApi.generateRecoveryPlan(recovery.id);
        } catch (_) {}
      }
      if (mounted) {
        context.go('/recovery/${recovery.id}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to start recovery: $e');
    } finally {
      if (mounted) setState(() => _isStartingRecovery = false);
    }
  }

  Future<void> _openEditDialog() async {
    final item = _item;
    if (item == null) return;

    if (_categories.isEmpty) {
      try {
        _categories = await _api.getCategories();
      } catch (_) {}
    }

    final nameController = TextEditingController(text: item.name);
    final brandController = TextEditingController(text: item.brand ?? '');
    final modelController = TextEditingController(text: item.model ?? '');
    final descController = TextEditingController(text: item.conditionDescription ?? '');
    String selectedCatId = item.categoryId;

    // Automatically pre-select recommended category if suggested by Agent 1
    final detectedCat = _categoryMismatch?['detectedCategory']?.toString().toLowerCase();
    if (detectedCat != null && detectedCat.isNotEmpty && _categoryMismatch?['inconsistencyType'] != 'DescriptionMismatch') {
      final matchingCat = _categories.cast<CategoryModel?>().firstWhere(
        (c) => c?.name.toLowerCase().contains(detectedCat) == true,
        orElse: () => null,
      );
      if (matchingCat != null) {
        selectedCatId = matchingCat.id;
      }
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDescMismatch = _categoryMismatch?['inconsistencyType'] == 'DescriptionMismatch';
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Edit Item Details',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_categoryMismatch != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Agent 1 Identified Issue:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _categoryMismatch!['reason']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Text('Item Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(hintText: 'e.g. iPhone 13 Pro Max'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Item name required' : null,
                        ),
                        const SizedBox(height: 12),

                        const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _categories.any((c) => c.id == selectedCatId)
                              ? selectedCatId
                              : (_categories.isNotEmpty ? _categories.first.id : null),
                          isExpanded: true,
                          items: _categories.map((c) {
                            final isRecommended = _categoryMismatch?['detectedCategory'] != null &&
                                !isDescMismatch &&
                                c.name.toLowerCase().contains(_categoryMismatch!['detectedCategory'].toString().toLowerCase());
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                isRecommended ? '${c.name} — Recommended by Agent 1' : c.name,
                                style: TextStyle(
                                  fontWeight: isRecommended ? FontWeight.bold : FontWeight.normal,
                                  color: isRecommended ? AppColors.primary : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCatId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Brand *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: brandController,
                                    decoration: const InputDecoration(hintText: 'e.g. Apple'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Model *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: modelController,
                                    decoration: const InputDecoration(hintText: 'e.g. A2643'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text('Physical & Operational Condition *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        if (isDescMismatch) ...[
                          const SizedBox(height: 2),
                          Text(
                            '✏️ Agent 1 flagged this description as inconsistent with your ${item.name}. Please enter the correct condition.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: descController,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: 'Describe physical condition, battery, screen, issues...'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Condition details required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDialogState(() => isSaving = true);
                          try {
                            await _api.updateItem(
                              id: item.id,
                              name: nameController.text.trim(),
                              brand: brandController.text.trim(),
                              model: modelController.text.trim(),
                              conditionDescription: descController.text.trim(),
                              categoryId: selectedCatId,
                            );
                            if (mounted) {
                              setState(() {
                                _categoryMismatch = null;
                                _errorMessage = null;
                                _statusMessage = 'Item details updated successfully! Click "Run Advisory Assessment" to re-assess.';
                              });
                              nav.pop();
                              await _loadItem();
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed to update item: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Update Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppShell(
        title: 'Item Assessment & Details',
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_item == null) {
      return AppShell(
        title: 'Item Details',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Item not found', style: TextStyle(fontSize: 16, color: AppColors.slateLight)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadItem, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    final eco = item.ecoAssessment;
    final assessment = item.assessment;

    final bool isEcoHarmful = eco?.isHarmfulToEnvironment == true;
    final bool isEcoAcknowledged = item.ecoHazardAcknowledged;
    final bool isDonationBlocked = eco?.canBeDonated == false && item.selectedRecoveryRoute == 'Donate';
    final bool isAssessmentLocked = (isEcoHarmful && !isEcoAcknowledged) || isDonationBlocked;

    return AppShell(
      title: 'Item Details: ${item.name}',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Reload',
        onPressed: _loadItem,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_statusMessage!, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ],

                // TOP ALERT: Category or Description Mismatch with DIRECT EDIT BUTTON
                if (_categoryMismatch != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _categoryMismatch!['inconsistencyType'] == 'DescriptionMismatch'
                                    ? 'Agent 1: Description Inconsistency Detected'
                                    : 'Agent 1: Category Mismatch Detected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openEditDialog,
                              icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                              label: Text(
                                _categoryMismatch!['inconsistencyType'] == 'DescriptionMismatch'
                                    ? 'Edit Description'
                                    : 'Edit Category',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _categoryMismatch!['reason']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), height: 1.4),
                        ),
                        if (_categoryMismatch!['detectedCategory'] != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  '💡 Recommended Category: ${_categoryMismatch!['detectedCategory']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                ),
                              ),
                              TextButton(
                                onPressed: _openEditDialog,
                                child: const Text(
                                  'Click here to apply & edit details →',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.rose50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.rose500.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.rose500, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.rose700, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                // 1. ENVIRONMENTAL HAZARD & ECO-AGENT BANNER
                if (eco != null) ...[
                  // --- HARMFUL: Not yet acknowledged ---
                  if (isEcoHarmful && !isEcoAcknowledged) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF87171)),
                        boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Environmental Hazard Detected',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF991B1B))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Text('${eco.hazardLevel.toUpperCase()} HAZARD LEVEL',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF991B1B))),
                              ),
                              const SizedBox(width: 8),
                              const Text('Action Required Before Assessment',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF991B1B), fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Alert text
                          Text(
                            eco.environmentalAlert.isNotEmpty ? eco.environmentalAlert : 'Hazardous components detected. Special handling required.',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D), height: 1.4),
                          ),

                          // Donation not permitted box
                          if (eco.canBeDonated == false) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('⚠️ Donation Not Permitted (Hazardous / Damaged Device)',
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF9F1239))),
                                        SizedBox(height: 4),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isSwitchingRoute ? null : _handleSwitchToRecycle,
                                    icon: Icon(_isSwitchingRoute ? Icons.hourglass_empty : Icons.sync, size: 14, color: Colors.white),
                                    label: Text(_isSwitchingRoute ? 'Switching...' : 'Switch Route to Recycle',
                                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE11D48),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              eco.donationUnsuitabilityReason ?? 'Due to the hazards identified, this item cannot be donated and must be safely recycled.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFBE123C)),
                            ),
                          ],

                          // Detected Hazardous Components
                          if (eco.detectedHazards.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text('DETECTED HAZARDOUS COMPONENTS:',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: eco.detectedHazards.map((hazard) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('⚠️ $hazard',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500)),
                              )).toList(),
                            ),
                          ],

                          // Mandatory Safety Precautions
                          if (eco.handlingPrecautions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(220),
                                border: Border.all(color: const Color(0xFFFECACA)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('MANDATORY SAFETY & ENVIRONMENTAL PRECAUTIONS:',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                                  const SizedBox(height: 8),
                                  ...eco.handlingPrecautions.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(color: Color(0xFF7F1D1D), fontWeight: FontWeight.bold)),
                                        Expanded(child: Text(p, style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4))),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],

                          // Action buttons
                          const SizedBox(height: 14),
                          if (eco.canBeDonated == false && item.selectedRecoveryRoute != 'Recycle') ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSwitchingRoute ? null : _handleSwitchToRecycle,
                                icon: const Icon(Icons.shield, size: 16, color: Colors.white),
                                label: Text(_isSwitchingRoute ? 'Switching to Recycle...' : 'Change Route to Recycle & Acknowledge Safety',
                                    style: const TextStyle(fontSize: 13, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isAcknowledgingEco ? null : _handleAcknowledgeEco,
                                icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                                label: Text(_isAcknowledgingEco ? 'Saving Acknowledgment...' : 'I Acknowledge These Environmental Precautions',
                                    style: const TextStyle(fontSize: 13, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _loadItem,
                            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF991B1B)),
                            label: const Text('Re-check Hazards', style: TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]

                  // --- HARMFUL: Acknowledged (but wrong route) ---
                  else if (isEcoHarmful && isEcoAcknowledged) ...[
                    Builder(builder: (ctx) {
                      final isWrongRoute = eco.canBeDonated == false && item.selectedRecoveryRoute == 'Donate';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: isWrongRoute ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                          border: Border(left: BorderSide(
                            color: isWrongRoute ? const Color(0xFFDC2626) : const Color(0xFFD97706), width: 4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user, size: 20, color: isWrongRoute ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Environmental Hazard Precautions Acknowledged (${eco.hazardLevel} Hazard Level)',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                                        color: isWrongRoute ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isWrongRoute
                                        ? '⚠️ This item cannot be donated due to hazard severity. Switch route to Recycle to proceed.'
                                        : 'Hazardous components logged for safe handling. Cleared for certified recycling.',
                                    style: TextStyle(fontSize: 11,
                                        color: isWrongRoute ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                            if (isWrongRoute) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isSwitchingRoute ? null : _handleSwitchToRecycle,
                                icon: const Icon(Icons.sync, size: 13, color: Colors.white),
                                label: Text(_isSwitchingRoute ? 'Switching...' : 'Switch to Recycle',
                                    style: const TextStyle(fontSize: 11, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ]

                  // --- NOT HARMFUL: Eco-safe green banner ---
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        border: const Border(left: BorderSide(color: Color(0xFF16A34A), width: 4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.eco, size: 20, color: Color(0xFF16A34A)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🌱 Eco-Safe & Circular Eligible',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF166534))),
                                SizedBox(height: 2),
                                Text('No critical environmental hazards detected. Device is cleared for standard circular recovery.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('~${eco.estimatedCo2OffsetKg.toStringAsFixed(0)} kg CO₂ Offset',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                        ],
                      ),
                    ),
                  ],
                ],

                // 2. ITEM OVERVIEW CARD
                Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slateDark),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openEditDialog,
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(label: item.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.brand ?? ""} • ${item.model ?? ""}'.trim(),
                          style: const TextStyle(fontSize: 13, color: AppColors.slateLight, fontWeight: FontWeight.w500),
                        ),
                        const Divider(height: 24),

                        // Photo Gallery Header & Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Item Photos (${item.images.length})',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.slateDark),
                            ),
                            if (item.status == 'Draft')
                              TextButton.icon(
                                onPressed: _uploadMorePhotos,
                                icon: const Icon(Icons.add_a_photo_outlined, size: 14),
                                label: const Text('Add Photo', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (item.images.isNotEmpty) ...[
                          SizedBox(
                            height: 140,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: item.images.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    ApiConstants.resolveImageUrl(item.images[i].url),
                                    height: 140,
                                    width: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 140,
                                      width: 140,
                                      color: AppColors.surfaceSubtle,
                                      child: const Icon(Icons.image_not_supported, color: AppColors.slateLight),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.photo_camera_outlined, color: AppColors.slateLight, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text('No item photos uploaded yet.', style: TextStyle(fontSize: 12, color: AppColors.slateLight)),
                                ),
                                if (item.status == 'Draft')
                                  ElevatedButton.icon(
                                    onPressed: _uploadMorePhotos,
                                    icon: const Icon(Icons.upload, size: 14),
                                    label: const Text('Upload Photo', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const Text('Condition Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slateDark)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.conditionDescription?.isNotEmpty == true ? item.conditionDescription! : 'No condition notes provided.',
                            style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. AGENT 1 ADVISORY ASSESSMENT CARD
                Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Agent 1 Advisory Assessment',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slateDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (assessment == null) ...[
                          const Text(
                            'The item assessment agent analyzes device characteristics, categories, and condition to provide an advisory recovery route recommendation.',
                            style: TextStyle(fontSize: 13, color: AppColors.slateLight, height: 1.4),
                          ),
                          const SizedBox(height: 14),

                          // If Agent 1 flagged category or description mismatch
                          if (_categoryMismatch != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _categoryMismatch!['inconsistencyType'] == 'DescriptionMismatch'
                                            ? 'Description Correction Needed'
                                            : 'Category Correction Needed',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _categoryMismatch!['inconsistencyType'] == 'DescriptionMismatch'
                                        ? 'Agent 1 detected that your condition description describes a different device. Please edit the description to describe your ${item.name}.'
                                        : 'Agent 1 detected that the item details do not match the selected category. Please edit the category before proceeding.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.4),
                                  ),
                                  if (_categoryMismatch!['reason'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _categoryMismatch!['reason']!.toString(),
                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF7F1D1D)),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: _openEditDialog,
                                    icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                    label: Text(
                                      _categoryMismatch!['inconsistencyType'] == 'DescriptionMismatch'
                                          ? 'Edit Description'
                                          : 'Edit Item Category',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Only show button if item is in a state the backend accepts
                          if (['Draft', 'Submitted', 'AssessmentPending'].contains(item.status)) ...[
                            if (isAssessmentLocked) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline, color: Color(0xFFDC2626), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isDonationBlocked
                                          ? 'Locked: Hazardous item must be switched to Recycle before evaluation.'
                                          : 'Locked: Environmental precautions must be acknowledged above.',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isAssessing ? null : _triggerAssessment,
                                icon: _isAssessing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                                label: Text(
                                  _isAssessing ? 'Evaluating with Agent 1...' : 'Run Advisory Assessment',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                          ] else ...[
                            // Item is in a non-assessable status but no assessment data — show info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.slateLight, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Assessment data unavailable for item in "${item.status}" status.',
                                      style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          // Assessment Results
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Estimated Condition', style: TextStyle(fontSize: 11, color: AppColors.slateLight)),
                                      const SizedBox(height: 4),
                                      Text(
                                        assessment.conditionLevel ?? (assessment.isConsistent ? 'Functional' : 'Defective'),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Advisory Route', style: TextStyle(fontSize: 11, color: AppColors.slateLight)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Recommended: ${assessment.recommendedRecoveryRoute}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF166534), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    assessment.reasoning.isNotEmpty ? assessment.reasoning : 'Agent 1 evaluated condition and advised ${assessment.recommendedRecoveryRoute}.',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 4. ROUTE SELECTION + GENERATE PREPARATION PLAN
                // Only show after assessment is done
                if (assessment == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.slateLight, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Run Agent 1 Advisory Assessment above to unlock route selection.',
                            style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Route selection card
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.route, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Confirm Your Preferred Route',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slateDark)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'You maintain full autonomy to choose your desired recovery path.',
                            style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final route in ['Donate', 'Recycle']) ...[
                                Expanded(
                                  child: Builder(builder: (ctx) {
                                    final isDonateBlocked = route == 'Donate' && eco?.canBeDonated == false;
                                    final effectiveRoute = item.selectedRecoveryRoute ??
                                        (eco?.canBeDonated == false
                                            ? 'Recycle'
                                            : (item.assessment?.recommendedRecoveryRoute.isNotEmpty == true
                                                ? item.assessment!.recommendedRecoveryRoute
                                                : 'Recycle'));
                                    final isSelected = effectiveRoute == route;
                                    return GestureDetector(
                                      onTap: (!isDonateBlocked && !_isSelectingRoute)
                                          ? () => _handleSelectRoute(route)
                                          : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : isDonateBlocked
                                                  ? const Color(0xFFF3F4F6)
                                                  : Colors.white,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : isDonateBlocked
                                                    ? const Color(0xFFD1D5DB)
                                                    : AppColors.border,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              route == 'Donate' ? Icons.volunteer_activism : Icons.recycling,
                                              color: isSelected
                                                  ? Colors.white
                                                  : isDonateBlocked
                                                      ? const Color(0xFF9CA3AF)
                                                      : AppColors.primary,
                                              size: 22,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              route,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: isSelected
                                                    ? Colors.white
                                                    : isDonateBlocked
                                                        ? const Color(0xFF9CA3AF)
                                                        : AppColors.slateDark,
                                              ),
                                            ),
                                            if (isDonateBlocked)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 2),
                                                child: Text('(Ineligible: Hazard)',
                                                    style: TextStyle(fontSize: 9, color: Color(0xFFDC2626))),
                                              ),
                                            if (isSelected)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 2),
                                                child: Icon(Icons.check_circle, color: Colors.white, size: 14),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                if (route == 'Donate') const SizedBox(width: 10),
                              ],
                            ],
                          ),

                          // Generate Plan button (always visible once assessment is completed, matching web app)
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isStartingRecovery ? null : _handleCreateRecovery,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isStartingRecovery) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Generating Preparation Plan...',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                    ),
                                  ] else ...[
                                    const Text(
                                      'Generate Preparation Plan (Agent 2)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
