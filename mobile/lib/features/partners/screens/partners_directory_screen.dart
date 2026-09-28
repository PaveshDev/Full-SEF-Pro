import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/partner_model.dart';
import '../services/partners_api_service.dart';

class PartnersDirectoryScreen extends StatefulWidget {
  const PartnersDirectoryScreen({super.key});

  @override
  State<PartnersDirectoryScreen> createState() => _PartnersDirectoryScreenState();
}

class _PartnersDirectoryScreenState extends State<PartnersDirectoryScreen> {
  final _partnersService = PartnersApiService();

  List<Partner> _partners = [];
  bool _loading = true;
  String? _error;
  String _selectedRoute = 'All';

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final routeParam = _selectedRoute == 'All' ? null : _selectedRoute;
      final partners = await _partnersService.getPartners(
        route: routeParam,
        activeOnly: true,
      );
      setState(() {
        _partners = partners;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load partners: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certified Partners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPartners,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Recycle'),
                const SizedBox(width: 8),
                _buildFilterChip('Donate'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: AppColors.rose500)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadPartners,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _partners.isEmpty
                        ? const Center(
                            child: Text(
                              'No partners found for this criteria.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _partners.length,
                            itemBuilder: (context, index) {
                              final partner = _partners[index];
                              return _buildPartnerCard(partner);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedRoute == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRoute = label;
          });
          _loadPartners();
        }
      },
    );
  }

  Widget _buildPartnerCard(Partner partner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partner.email,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Certified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    partner.serviceArea ?? 'Islandwide Coverage',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.timelapse, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Avg ${partner.averageProcessingDays} days',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),

            if (partner.services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: partner.services.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      s.recoveryRoute,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate700),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
