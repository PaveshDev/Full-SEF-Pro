import 'package:flutter/material.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';

class AdminCollectionAgentsScreen extends StatefulWidget {
  const AdminCollectionAgentsScreen({super.key});

  @override
  State<AdminCollectionAgentsScreen> createState() => _AdminCollectionAgentsScreenState();
}

class _AdminCollectionAgentsScreenState extends State<AdminCollectionAgentsScreen> {
  final _dio = ApiClient().dio;
  List<dynamic> _agents = [];
  bool _loading = true;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/admin/collection-agents');
      if (mounted) {
        setState(() {
          _agents = res.data as List;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load collection agents.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final name = agent['name'] ?? 'Agent';
    final profileId = agent['profileId'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Collection Agent'),
        content: Text('Are you sure you want to permanently delete agent "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dio.delete('/admin/collection-agents/$profileId');
      if (mounted) {
        setState(() => _success = 'Collection agent "$name" deleted successfully.');
        await _loadAgents();
      }
    } catch (err) {
      if (mounted) setState(() => _error = 'Failed to delete collection agent.');
    }
  }

  void _showAddEditModal([Map<String, dynamic>? agent]) {
    final isEdit = agent != null;
    final nameController = TextEditingController(text: agent?['name'] ?? '');
    final emailController = TextEditingController(text: agent?['email'] ?? '');
    final passwordController = TextEditingController();
    final phoneController = TextEditingController(text: agent?['phone'] ?? '');
    final areaController = TextEditingController(text: agent?['serviceArea'] ?? '');
    final townController = TextEditingController(text: agent?['townArea'] ?? '');
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
                          isEdit ? 'Edit Collection Agent' : 'Register Collection Agent',
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

                    if (!isEdit) ...[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Full Name *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email Address *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password *',
                          hintText: 'Min 8 chars, 1 uppercase, 1 digit',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: '0771234567 or +94771234567',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaController,
                      decoration: const InputDecoration(labelText: 'Service Territory / District *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: townController,
                      decoration: const InputDecoration(labelText: 'Town Area / Vicinity *'),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final rawPhone = phoneController.text.trim();
                                final serviceArea = areaController.text.trim();
                                final townArea = townController.text.trim();

                                if (rawPhone.isEmpty || serviceArea.isEmpty || townArea.isEmpty) {
                                  setSheetState(() => formError = 'Please fill all required fields.');
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
                                  final name = nameController.text.trim();
                                  final email = emailController.text.trim();
                                  final password = passwordController.text;

                                  if (name.isEmpty || email.isEmpty || password.isEmpty) {
                                    setSheetState(() => formError = 'Please fill all required fields.');
                                    return;
                                  }

                                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                                    setSheetState(() => formError = 'Please enter a valid email address.');
                                    return;
                                  }

                                  if (password.length < 8 || !RegExp(r'[A-Z]').hasMatch(password) || !RegExp(r'[0-9]').hasMatch(password)) {
                                    setSheetState(() => formError = 'Password must be 8+ characters with uppercase and digit.');
                                    return;
                                  }
                                }

                                setSheetState(() {
                                  saving = true;
                                  formError = null;
                                });

                                try {
                                  if (isEdit) {
                                    await _dio.put(
                                      '/admin/collection-agents/${agent['profileId']}',
                                      data: {
                                        'phone': cleanPhone,
                                        'serviceArea': serviceArea,
                                        'townArea': townArea,
                                        'isActive': agent['isActive'] ?? true,
                                      },
                                    );
                                  } else {
                                    await _dio.post(
                                      '/admin/collection-agents',
                                      data: {
                                        'name': nameController.text.trim(),
                                        'email': emailController.text.trim(),
                                        'password': passwordController.text,
                                        'phone': cleanPhone,
                                        'serviceArea': serviceArea,
                                        'townArea': townArea,
                                      },
                                    );
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    setState(() => _success = isEdit ? 'Agent updated successfully.' : 'Agent registered successfully.');
                                    await _loadAgents();
                                  }
                                } catch (err) {
                                  String errorMsg = 'Failed to save collection agent.';
                                  try {
                                    final dynamic errObj = (err as dynamic).response?.data;
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
                          saving ? 'Saving...' : (isEdit ? 'Save Profile' : 'Register Agent'),
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
      title: 'Collection Agents',
      action: ElevatedButton.icon(
        onPressed: () => _showAddEditModal(),
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Add Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAgents,
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
                          'Collection Agent Fleet',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage registered physical pickup agents, territories, and availability status',
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

                    if (_agents.isEmpty)
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
                            Icon(Icons.group_outlined, size: 48, color: AppColors.primary),
                            SizedBox(height: 14),
                            Text(
                              'No collection agents registered yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _agents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final a = _agents[idx] as Map<String, dynamic>;
                          final name = a['name'] ?? 'Agent';
                          final area = a['serviceArea'] ?? '';
                          final town = a['townArea'] ?? 'All towns';
                          final email = a['email'] ?? '';
                          final phone = a['phone'] ?? 'No phone';
                          final isAvailable = a['isAvailable'] == true;
                          final isActive = a['isActive'] == true;

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
                                              '$area • $town',
                                              style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          StatusBadge(status: isAvailable ? 'Available' : 'Busy'),
                                          StatusBadge(status: isActive ? 'Active' : 'Inactive'),
                                        ],
                                      ),
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
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _showAddEditModal(a),
                                        tooltip: 'Edit Profile',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                                        onPressed: () => _deleteAgent(a),
                                        tooltip: 'Delete Agent',
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
