import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/api_constants.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _townController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedDistrict = 'Colombo';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _townController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Live password validation checks matching RegisterPage.jsx
  bool get _passLengthOk => _passwordController.text.length >= 8;
  bool get _passUpperOk => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _passDigitOk => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_passLengthOk || !_passUpperOk || !_passDigitOk || !_passwordsMatch) {
      setState(() => _errorMessage = 'Please fulfill all password requirements.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      var cleanPhone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
      if (cleanPhone.startsWith('+94')) {
        cleanPhone = '0${cleanPhone.substring(3)}';
      }
      await auth.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: cleanPhone,
        address: _addressController.text.trim(),
        district: _selectedDistrict,
        town: _townController.text.trim(),
      );

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand Header matching RegisterPage.jsx
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.repeat, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create Customer Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your details for convenient e-waste collection and pickup',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.slateLight),
                  ),
                  const SizedBox(height: 24),

                  // Main Registration Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.rose50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.rose500.withAlpha(80)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.rose500, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.rose700, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Full Name
                          const Text('Full Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'Kasun Silva',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 2) return 'Full name must be at least 2 characters.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email Address
                          const Text('Email Address *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'kasun@example.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Email address is required.';
                              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(val.trim())) return 'Please enter a valid email address.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone Number
                          const Text('Phone Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '0771234567 or +94771234567',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Phone number is required.';
                              var clean = val.replaceAll(RegExp(r'[\s\-()]'), '');
                              if (clean.startsWith('+94')) {
                                clean = '0${clean.substring(3)}';
                              }
                              if (!RegExp(r'^[0-9]{10}$').hasMatch(clean)) return 'Phone number must be exactly 10 digits (e.g. 0771234567).';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password & Confirm Password
                          const Text('Password *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('Confirm Password *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Password Requirements Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Password Requirements:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slateDark)),
                                const SizedBox(height: 6),
                                _buildRuleItem('8+ characters', _passLengthOk),
                                _buildRuleItem('One uppercase (A-Z)', _passUpperOk),
                                _buildRuleItem('One number (0-9)', _passDigitOk),
                                _buildRuleItem('Passwords match', _passwordsMatch),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // District (Sri Lanka)
                          const Text('District *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedDistrict,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.map_outlined, size: 20),
                            ),
                            items: ApiConstants.sriLankanDistricts.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDistrict = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Town / City
                          const Text('Town / City *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _townController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Kollupitiya, Akkaraipattu',
                              prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                            ),
                            validator: (val) => val == null || val.trim().length < 2 ? 'Town or city is required.' : null,
                          ),
                          const SizedBox(height: 16),

                          // Pickup Street Address
                          const Text('Pickup Street Address *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'e.g. No. 45, Galle Road, 2nd Floor',
                              prefixIcon: Icon(Icons.home_outlined, size: 20),
                            ),
                            validator: (val) => val == null || val.trim().length < 5 ? 'Please provide a complete street address (minimum 5 characters).' : null,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Used by collection agents to navigate and pick up your items.',
                            style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                          ),
                          const SizedBox(height: 24),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleRegister,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                              label: Text(
                                _isLoading ? 'Creating account...' : 'Register as Customer',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/login'),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isSatisfied ? AppColors.success : AppColors.slateLight,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isSatisfied ? AppColors.success : AppColors.slateLight,
              fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
