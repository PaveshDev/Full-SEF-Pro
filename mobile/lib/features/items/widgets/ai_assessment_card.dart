import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/item_model.dart';

class AiAssessmentCard extends StatelessWidget {
  final AiAssessmentModel assessment;

  const AiAssessmentCard({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FAF9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: assessment.isConsistent ? AppColors.primary : AppColors.warning,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: assessment.isConsistent ? AppColors.primary : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Gemini AI Item Assessment',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.slateDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: assessment.isConsistent ? AppColors.successBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: assessment.isConsistent ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  child: Text(
                    assessment.isConsistent ? 'Consistent' : 'Mismatch Flagged',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: assessment.isConsistent ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Discrepancy Alert if flagged
            if (!assessment.isConsistent && assessment.flaggedMismatches.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Potential Discrepancy Detected:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                          ),
                          const SizedBox(height: 2),
                          ...assessment.flaggedMismatches.map((m) => Text(
                                '• $m',
                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Valuation & Route Recommendation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Value',
                          style: TextStyle(fontSize: 11, color: AppColors.slateLight, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          assessment.estimatedRecoveryValue != null
                              ? 'LKR ${assessment.estimatedRecoveryValue!.toStringAsFixed(2)}'
                              : 'Pending Quote',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppColors.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommended Route',
                          style: TextStyle(fontSize: 11, color: AppColors.slateLight, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          assessment.recommendedRecoveryRoute,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slateDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // AI Reasoning
            if (assessment.reasoning.isNotEmpty) ...[
              Text(
                'AI Analysis: ${assessment.reasoning}',
                style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
