import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/auth/auth_provider.dart';
import '../services/collections_api_service.dart';

class SchedulePickupScreen extends StatefulWidget {
  final String recoveryId;

  const SchedulePickupScreen({
    super.key,
    required this.recoveryId,
  });

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  final _collectionsService = CollectionsApiService();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _selectedSlotIndex = 0;
  bool _submitting = false;
  String? _error;

  final List<Map<String, String>> _timeSlots = [
    {'label': 'Morning Window', 'time': '09:00 AM - 12:00 PM', 'start': '09:00:00', 'end': '12:00:00'},
    {'label': 'Afternoon Window', 'time': '01:00 PM - 04:00 PM', 'start': '13:00:00', 'end': '16:00:00'},
    {'label': 'Evening Window', 'time': '04:00 PM - 07:00 PM', 'start': '16:00:00', 'end': '19:00:00'},
  ];

  Future<void> _submitSchedule() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final slot = _timeSlots[_selectedSlotIndex];
      await _collectionsService.createCollectionPreference(
        widget.recoveryId,
        pickupDate: _selectedDate,
        startTime: slot['start']!,
        endTime: slot['end']!,
      );

      if (mounted) {
        context.pushReplacement('/collections/pass/${widget.recoveryId}');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit pickup preference: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return AppShell(
      title: 'Schedule Doorstep Pickup',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Dispatch banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.slate900, AppColors.slate800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping, color: Colors.greenAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agent 4: Smart Dispatch',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'AI routes certified collection agents according to your district for carbon-efficient doorstep pickup.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.rose500),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.rose500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.rose700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Pickup location details
            const Text(
              'Doorstep Pickup Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
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
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${user?.address ?? "Address on file"}, ${user?.town ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      'District: ${user?.district ?? "Colombo"} • Phone: ${user?.phone ?? "Not set"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select Date
            const Text(
              'Preferred Pickup Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Select Time Slot
            const Text(
              'Preferred Time Window',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _timeSlots.length; i++) ...[
              InkWell(
                onTap: () => setState(() => _selectedSlotIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSlotIndex == i ? AppColors.primary : AppColors.border,
                      width: _selectedSlotIndex == i ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedSlotIndex == i ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _selectedSlotIndex == i ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _timeSlots[i]['label']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _timeSlots[i]['time']!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitSchedule,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code, color: Colors.white),
                label: Text(
                  _submitting ? 'Dispatching AI Plan...' : 'Confirm Pickup & Generate Pass',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
