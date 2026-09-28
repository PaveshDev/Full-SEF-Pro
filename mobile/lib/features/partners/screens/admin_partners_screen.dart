import 'package:flutter/material.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';

class AdminPartnersScreen extends StatefulWidget {
  const AdminPartnersScreen({super.key});

  @override
  State<AdminPartnersScreen> createState() => _AdminPartnersScreenState();
}

class _AdminPartnersScreenState extends State<AdminPartnersScreen> {
  final _dio = ApiClient().dio;
  List<dynamic> _partners = [];
  List<dynamic> _categories = [];
  bool _loading = true;
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
      final pRes = await _dio.get('/partners', queryParameters: {'activeOnly': false});
      final cRes = await _dio.get('/categories');
      if (mounted) {
        setState(() {
          _partners = pRes.data as List;
          _categories = cRes.data as List;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load partners data.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deletePartner(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Partner'),
        content: Text('Are you sure you want to deactivate "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dio.delete('/partners/$id');
      if (mounted) {
        setState(() => _success = 'Partner deactivated successfully.');
        await _loadData();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to delete partner.');
    }
  }

  Future<void> _reactivatePartner(String id) async {
    try {
      await _dio.post('/partners/$id/reactivate');
      if (mounted) {
        setState(() => _success = 'Partner reactivated.');
        await _loadData();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to reactivate partner.');
    }
  }

  void _showAddEditModal([Map<String, dynamic>? partner]) {
    final isEdit = partner != null;
    final nameCtrl = TextEditingController(text: partner?['name'] ?? '');
    final contactCtrl = TextEditingController(text: partner?['contactName'] ?? '');
    final emailCtrl = TextEditingController(text: partner?['email'] ?? '');
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: partner?['phone'] ?? '');
    final areaCtrl = TextEditingController(text: partner?['serviceArea'] ?? '');
    final hoursCtrl = TextEditingController(text: partner?['operatingHours'] ?? 'Mon-Fri 9:00-17:00');

    // services: [{recoveryRoute, categoryId}]
    List<Map<String, dynamic>> selectedServices = [];
    if (isEdit && partner['services'] != null) {
      for (final s in partner['services'] as List) {
        selectedServices.add({
          'recoveryRoute': s['recoveryRoute'],
          'categoryId': s['categoryId'],
        });
      }
    }

    String? formError;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            bool isSelected(String route, String catId) =>
                selectedServices.any((s) => s['recoveryRoute'] == route && s['categoryId'] == catId);

            void toggleService(String route, String catId) {
              setSheetState(() {
                if (isSelected(route, catId)) {
                  selectedServices.removeWhere((s) => s['recoveryRoute'] == route && s['categoryId'] == catId);
                } else {
                  selectedServices.add({'recoveryRoute': route, 'categoryId': catId});
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Partner Details' : 'Register New Partner',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slateDark),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),

                    if (formError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.roseLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(formError!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
                      ),

                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Organization Name *')),
                    const SizedBox(height: 10),
                    TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person *')),
                    const SizedBox(height: 10),
                    TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Official Email *')),
                    const SizedBox(height: 10),

                    if (!isEdit) ...[
                      TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Login Password * (Min 8 chars, 1 uppercase, 1 digit)')),
                      const SizedBox(height: 10),
                      TextField(controller: confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password *')),
                      const SizedBox(height: 10),
                    ],

                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number *', hintText: '0771234567 or +94771234567')),
                    const SizedBox(height: 10),
                    TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'Service Area / District *')),
                    const SizedBox(height: 10),
                    TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: 'Operating Hours *', hintText: 'e.g. Mon-Fri 9:00-17:00')),
                    const SizedBox(height: 16),

                    const Text(
                      'Accepted Services & Categories *',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                    ),
                    const SizedBox(height: 8),

                    // Recycle Category Chips
                    const Text('Recycle Route:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categories.map((c) {
                        final catId = c['id'].toString();
                        final catName = c['name'] ?? '';
                        final active = isSelected('Recycle', catId);
                        return FilterChip(
                          label: Text(catName, style: TextStyle(fontSize: 11, color: active ? Colors.white : AppColors.slateDark)),
                          selected: active,
                          selectedColor: AppColors.emerald,
                          onSelected: (_) => toggleService('Recycle', catId),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Donate Category Chips
                    const Text('Donate Route:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categories.map((c) {
                        final catId = c['id'].toString();
                        final catName = c['name'] ?? '';
                        final active = isSelected('Donate', catId);
                        return FilterChip(
                          label: Text(catName, style: TextStyle(fontSize: 11, color: active ? Colors.white : AppColors.slateDark)),
                          selected: active,
                          selectedColor: AppColors.info,
                          onSelected: (_) => toggleService('Donate', catId),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final contact = contactCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final rawPhone = phoneCtrl.text.trim();
                                final serviceArea = areaCtrl.text.trim();
                                final operatingHours = hoursCtrl.text.trim();

                                if (name.isEmpty || contact.isEmpty || email.isEmpty || rawPhone.isEmpty || serviceArea.isEmpty || operatingHours.isEmpty) {
                                  setSheetState(() => formError = 'Please fill all required fields.');
                                  return;
                                }

                                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                                  setSheetState(() => formError = 'Please enter a valid official email address.');
                                  return;
                                }

                                var cleanPhone = rawPhone.replaceAll(RegExp(r'[\s\-()]'), '');
                                if (cleanPhone.startsWith('+94')) {
                                  cleanPhone = '0${cleanPhone.substring(3)}';
                                }
                                if (!RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone)) {
                                  setSheetState(() => formError = 'Phone number must be exactly 10 digits (e.g. 0771234567).');
                                  return;
                                }

                                if (!isEdit) {
                                  final pass = passCtrl.text;
                                  final confirm = confirmPassCtrl.text;
                                  if (pass.length < 8 || !RegExp(r'[A-Z]').hasMatch(pass) || !RegExp(r'[0-9]').hasMatch(pass)) {
                                    setSheetState(() => formError = 'Password must be 8+ characters with uppercase and digit.');
                                    return;
                                  }
                                  if (pass != confirm) {
                                    setSheetState(() => formError = 'Passwords do not match.');
                                    return;
                                  }
                                }

                                if (selectedServices.isEmpty) {
                                  setSheetState(() => formError = 'Please select at least one accepted category.');
                                  return;
                                }

                                setSheetState(() {
                                  saving = true;
                                  formError = null;
                                });

                                try {
                                  final payload = {
                                    'name': name,
                                    'contactName': contact,
                                    'email': email,
                                    'phone': cleanPhone,
                                    'serviceArea': serviceArea,
                                    'operatingHours': operatingHours,
                                    'services': selectedServices,
                                  };

                                  if (isEdit) {
                                    await _dio.put('/partners/${partner['id']}', data: {
                                      ...payload,
                                      'isActive': partner['isActive'] ?? true,
                                    });
                                  } else {
                                    await _dio.post('/partners', data: {
                                      ...payload,
                                      'password': passCtrl.text,
                                    });
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    setState(() => _success = isEdit ? 'Partner updated successfully.' : 'Partner registered successfully.');
                                    await _loadData();
                                  }
                                } catch (e) {
                                  String errorMsg = 'Failed to save partner organization.';
                                  try {
                                    final dynamic errObj = (e as dynamic).response?.data;
                                    if (errObj is Map && errObj['error'] != null) {
                                      errorMsg = errObj['error'].toString();
                                    }
                                  } catch (_) {}
                                  setSheetState(() {
                                    saving = false;
                                    formError = errorMsg;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          saving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create Partner'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Partners Management',
      action: ElevatedButton.icon(
        onPressed: () => _showAddEditModal(),
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Add Partner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
                          'Certified Recovery Partners',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage accredited electronics recyclers and charitable donation partner facilities',
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

                    if (_partners.isEmpty)
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
                            Icon(Icons.business_outlined, size: 48, color: AppColors.primary),
                            SizedBox(height: 14),
                            Text(
                              'No partners registered yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _partners.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final p = _partners[idx] as Map<String, dynamic>;
                          final id = p['id'].toString();
                          final name = p['name'] ?? 'Partner';
                          final contact = p['contactName'] ?? '';
                          final area = p['serviceArea'] ?? '';
                          final email = p['email'] ?? '';
                          final phone = p['phone'] ?? 'No phone';
                          final hours = p['operatingHours'] ?? 'Standard';
                          final isActive = p['isActive'] == true;

                          final services = (p['services'] as List?) ?? [];
                          final routes = services.map((s) => s['recoveryRoute']?.toString()).toSet();

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
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.slateDark,
                                              ),
                                            ),
                                            Text(
                                              'Contact: $contact • $area',
                                              style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(status: isActive ? 'Active' : 'Inactive'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.email_outlined, size: 14, color: AppColors.slateLight),
                                      const SizedBox(width: 4),
                                      Text(email, style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.slateLight),
                                      const SizedBox(width: 4),
                                      Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 14, color: AppColors.slateLight),
                                      const SizedBox(width: 4),
                                      Text(hours, style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    children: routes.map((r) => StatusBadge(status: r ?? '')).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _showAddEditModal(p),
                                        tooltip: 'Edit Partner',
                                      ),
                                      if (isActive)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                                          onPressed: () => _deletePartner(id, name),
                                          tooltip: 'Deactivate',
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.emerald),
                                          onPressed: () => _reactivatePartner(id),
                                          tooltip: 'Reactivate',
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
}
