import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String? label;
  final String? status;
  final String type; // 'status' or 'route'
  final Color? color;
  final Color? backgroundColor;

  const StatusBadge({
    super.key,
    this.label,
    this.status,
    this.type = 'status',
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = status ?? label ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final s = text.toLowerCase();
    Color textColor = const Color(0xFF4B5563);
    Color bg = const Color(0xFFF3F4F6);

    if (type == 'route' || s == 'donate' || s == 'recycle') {
      if (s.contains('donate')) {
        bg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
      } else if (s.contains('recycle')) {
        bg = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
      }
    } else {
      if (s.contains('draft')) {
        bg = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF4B5563);
      } else if (s.contains('submitted')) {
        bg = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
      } else if (s.contains('assessed')) {
        bg = const Color(0xFFEDE9FE);
        textColor = const Color(0xFF6D28D9);
      } else if (s.contains('pending') || s.contains('requested') && !s.contains('revision')) {
        bg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
      } else if (s.contains('approved')) {
        bg = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
      } else if (s.contains('rejected')) {
        bg = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
      } else if (s.contains('revision')) {
        bg = const Color(0xFFFFEDD5);
        textColor = const Color(0xFFC2410C);
      } else if (s.contains('scheduled')) {
        bg = const Color(0xFFE0E7FF);
        textColor = const Color(0xFF4338CA);
      } else if (s.contains('assigned')) {
        bg = const Color(0xFFCCFBF1);
        textColor = const Color(0xFF0F766E);
      } else if (s.contains('collected')) {
        bg = const Color(0xFFF3E8FF);
        textColor = const Color(0xFF7E22CE);
      } else if (s.contains('delivered') || s.contains('partnerreceived') || s.contains('handover')) {
        bg = const Color(0xFFE0E7FF);
        textColor = const Color(0xFF3730A3);
      } else if (s.contains('completed')) {
        bg = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
      } else if (s.contains('plangenerated')) {
        bg = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
      }
    }

    if (color != null) textColor = color!;
    if (backgroundColor != null) bg = backgroundColor!;

    String displayLabel = text.toUpperCase();
    if (s == 'agentassigned') {
      displayLabel = 'AGENT ASSIGNED';
    } else if (s == 'collected') {
      displayLabel = 'ITEM PICKED UP';
    } else if (s == 'deliveredtopartner' || s == 'handed over to partner' || s == 'handedovertopartner') {
      displayLabel = 'WAITING FOR PARTNER REVIEW & CONFIRMATION';
    } else if (s == 'partnerreceived') {
      displayLabel = 'PARTNER RECEIVED';
    } else if (s == 'plangenerated') {
      displayLabel = 'PLANGENERATED';
    } else if (s == 'pendingadminapproval') {
      displayLabel = 'PENDING REVIEW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayLabel,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

