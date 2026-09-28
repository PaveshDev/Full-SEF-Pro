import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/partner_model.dart';

class PartnerMatchCard extends StatelessWidget {
  final PartnerMatch match;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool isLoading;

  const PartnerMatchCard({
    super.key,
    required this.match,
    required this.isSelected,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isRankOne = match.rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : isRankOne
                  ? AppColors.primary.withAlpha(80)
                  : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withAlpha(25)
                : Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with rank badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isRankOne
                                  ? AppColors.primary
                                  : AppColors.slate700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isRankOne) ...[
                                  const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isRankOne ? '#1 Top AI Match' : 'Rank #${match.rank}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.emerald50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.emerald500),
                              ),
                              child: const Text(
                                'Selected Partner',
                                style: TextStyle(
                                  color: AppColors.emerald700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        match.partnerName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              match.serviceArea ?? 'Islandwide Service',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '~${match.averageProcessingDays}d processing',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
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

          // AI Evaluation rationale
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isRankOne ? AppColors.emerald50.withAlpha(120) : AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border.withAlpha(120)),
                bottom: BorderSide(color: AppColors.border.withAlpha(120)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: isRankOne ? AppColors.emerald700 : AppColors.slate600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI MATCH RATIONALE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isRankOne ? AppColors.emerald700 : AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        match.reason,
                        style: TextStyle(
                          fontSize: 13,
                          color: isRankOne ? AppColors.emerald900 : AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onSelect,
                icon: Icon(
                  isSelected ? Icons.check_circle : Icons.handshake_outlined,
                  size: 16,
                  color: isSelected ? AppColors.emerald700 : Colors.white,
                ),
                label: Text(
                  isSelected ? 'Partner Selected' : 'Choose This Partner',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.emerald700 : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? AppColors.emerald50 : AppColors.primary,
                  foregroundColor: isSelected ? AppColors.emerald700 : Colors.white,
                  side: isSelected ? const BorderSide(color: AppColors.emerald500) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
