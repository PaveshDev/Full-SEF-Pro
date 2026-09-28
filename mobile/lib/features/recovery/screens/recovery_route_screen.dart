import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../services/recovery_api_service.dart';

class RecoveryRouteScreen extends StatefulWidget {
  final String itemId;

  const RecoveryRouteScreen({super.key, required this.itemId});

  @override
  State<RecoveryRouteScreen> createState() => _RecoveryRouteScreenState();
}

class _RecoveryRouteScreenState extends State<RecoveryRouteScreen> {
  final RecoveryApiService _api = RecoveryApiService();
  String _selectedRoute = 'Recycle';
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleConfirmRoute() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _api.selectItemRoute(widget.itemId, _selectedRoute);
      final recovery = await _api.createRecoveryRequest(widget.itemId);
      if (mounted) {
        context.go('/recovery/${recovery.id}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not lock in recovery route: $e';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildRouteCard({
    required String route,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> benefits,
  }) {
    final isSelected = _selectedRoute == route;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedRoute = route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: isSelected ? Colors.white : AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.primary : AppColors.slateDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
                      ],
                    ),
                  ),
                  Radio<String>(
                    value: route,
                    groupValue: _selectedRoute,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRoute = val);
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              ...benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(b, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Select Circular Recovery Route',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose Circular Pathway',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select how you want LoopWorth certified circular facilities to process your device.',
                  style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.rose50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.rose500.withAlpha(80)),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.rose700, fontSize: 13)),
                  ),
                ],

                // Route 1: Recycle
                _buildRouteCard(
                  route: 'Recycle',
                  title: 'Material Recycling & Harvesting',
                  subtitle: 'End-of-life recovery and zero-landfill processing',
                  icon: Icons.recycling_rounded,
                  benefits: [
                    'Component harvesting (RAM, screens, controllers) for spare part recovery',
                    'Safe extraction of precious metals (Gold, Silver, Copper, Lithium)',
                    'Certified hazardous material neutralization (heavy metals, battery chemicals)',
                  ],
                ),
                const SizedBox(height: 16),

                // Route 2: Donate / Refurbish
                _buildRouteCard(
                  route: 'Donate',
                  title: 'Refurbish & Community Donation',
                  subtitle: 'Certified repair for education and community reuse',
                  icon: Icons.volunteer_activism_rounded,
                  benefits: [
                    'Certified data wipe following DoD/NIST protocols',
                    'Refurbishing for schools, rural learning labs, and non-profits',
                    'Prolongs electronics lifecycle to reduce carbon footprints',
                  ],
                ),
                const SizedBox(height: 24),

                // Action: Confirm Route & Trigger Agent 2
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleConfirmRoute,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text(
                    _isSubmitting ? 'Generating Plan...' : 'Generate Preparation Plan (Agent 2)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
