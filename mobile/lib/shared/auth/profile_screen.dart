import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_shell.dart';
import '../../core/config/api_constants.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _townController;
  String? _selectedDistrict;

  bool _isSaving = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _townController = TextEditingController(text: user?.town ?? '');
    _selectedDistrict = user?.district.isNotEmpty == true ? user?.district : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _townController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      var cleanPhone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
      if (cleanPhone.startsWith('+94')) {
        cleanPhone = '0${cleanPhone.substring(3)}';
      }
      await auth.updateProfile(
        name: _nameController.text.trim(),
        phone: cleanPhone,
        district: _selectedDistrict,
        town: _townController.text.trim(),
        address: _addressController.text.trim(),
      );

      final isAdmin = auth.user?.role == 'Admin';
      setState(() {
        _successMessage = isAdmin
            ? 'Admin profile and contact details have been updated successfully.'
            : 'Your profile and pickup details have been updated successfully.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isAdmin = user?.role == 'Admin';

    return AppShell(
      title: isAdmin ? 'Admin Profile' : 'My Profile',
      action: IconButton(
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        tooltip: 'Sign Out',
        onPressed: () async {
          await auth.logout();
          if (context.mounted) context.go('/login');
        },
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Header
                  Text(
                    isAdmin ? 'Administrator Profile & Contact Details' : 'Account & Pickup Details',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin
                        ? 'Manage your administrative credentials, official contact phone number, and headquarters location.'
                        : 'Manage your personal information and default pickup address used for collection agent dispatch.',
                    style: const TextStyle(fontSize: 13, color: AppColors.slateLight),
                  ),
                  const SizedBox(height: 16),

                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_successMessage!, style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Card 1: Identity Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isAdmin ? 'Administrator Information' : 'Personal Information',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          Text(isAdmin ? 'Administrator Name *' : 'Full Name *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: isAdmin ? 'System Admin' : 'Full Name',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                          ),
                          const SizedBox(height: 12),

                          const Text('Email Address (Account Identifier)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: user?.email ?? '',
                            enabled: false,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                              filled: true,
                              fillColor: AppColors.surfaceSubtle,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Role chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Account Role: ',
                                  style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                                ),
                                Text(
                                  user?.role ?? 'Customer',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 2: Contact & Office / Doorstep Address
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isAdmin ? 'Administrative Office & Contact Information' : 'Doorstep Pickup & Contact Information',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAdmin
                                ? 'These details represent your official administrative office and direct contact phone for platform management and system communications.'
                                : 'These details are essential for our collection agents to navigate and coordinate doorstep pickups.',
                            style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                          ),
                          const Divider(height: 24),

                          Text(isAdmin ? 'Official Phone Number *' : 'Contact Phone Number *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: isAdmin ? '0757809030' : '+94 77 123 4567',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Phone number is required';
                              var clean = val.replaceAll(RegExp(r'[\s\-()]'), '');
                              if (clean.startsWith('+94')) {
                                clean = '0${clean.substring(3)}';
                              }
                              if (!RegExp(r'^[0-9]{10}$').hasMatch(clean)) {
                                return 'Phone number must be exactly 10 digits (e.g. 0771234567)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          Text(isAdmin ? 'Operating District (Sri Lanka) *' : 'District (Sri Lanka) *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedDistrict,
                            decoration: const InputDecoration(
                              hintText: '-- Select District --',
                              prefixIcon: Icon(Icons.business_outlined, size: 18),
                            ),
                            items: ApiConstants.sriLankanDistricts.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedDistrict = val),
                            validator: (val) => val == null ? 'District is required' : null,
                          ),
                          const SizedBox(height: 12),

                          Text(isAdmin ? 'City / Town Area *' : 'Town / City / Area *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _townController,
                            decoration: InputDecoration(
                              hintText: isAdmin ? 'e.g. Colombo 03' : 'e.g. Nugegoda, Kollupitiya',
                              prefixIcon: const Icon(Icons.map_outlined, size: 18),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Town is required' : null,
                          ),
                          const SizedBox(height: 12),

                          Text(isAdmin ? 'Office / Headquarters Address *' : 'Street Address & Landmark *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              hintText: isAdmin ? 'e.g. No. 45/2, Galle Road' : 'e.g. No. 45, Baseline Road',
                              prefixIcon: const Icon(Icons.home_outlined, size: 18),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 3: Role-Specific Summary Card
                  if (isAdmin) ...[
                    Card(
                      color: const Color(0xFFF8FAF9),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Administrator Profile Summary',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Official platform administrator credentials and operational office registered on LoopWorth:',
                              style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _nameController.text.isNotEmpty ? _nameController.text : 'System Admin',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('Super Admin', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Office Base: ${_townController.text.isNotEmpty ? _townController.text : "Colombo 03"}, ${_selectedDistrict ?? "Colombo"}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Contact Phone: ${_phoneController.text.isNotEmpty ? _phoneController.text : "0757809030"}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_city, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _addressController.text.isNotEmpty
                                              ? '${_addressController.text}, ${_townController.text}, ${_selectedDistrict ?? "Colombo"}'
                                              : 'No. 45/2, Galle Road, Colombo 03, Colombo',
                                          style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      color: const Color(0xFFF8FAF9),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Live Agent View Preview',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'This is how your pickup details will be displayed to collection agents on their job dispatch card:',
                              style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _nameController.text.isNotEmpty ? _nameController.text : 'Customer Name',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        _phoneController.text.isNotEmpty ? _phoneController.text : '+94 XX XXX XXXX',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pickup Location: ${_townController.text.isNotEmpty ? _townController.text : "Town"}, ${_selectedDistrict ?? "District"}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _addressController.text.isNotEmpty ? _addressController.text : 'Street address',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Profile Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
