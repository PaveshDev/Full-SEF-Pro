import 'package:flutter/material.dart';

class AppColors {
  // Primary Emerald Greens
  static const Color primary = Color(0xFF166534); // #166534
  static const Color primaryLight = Color(0xFF15803D); // #15803D
  static const Color primaryAccent = Color(0xFF22C55E); // #22C55E
  static const Color primarySubtle = Color(0xFFDCFCE7); // #DCFCE7

  // Dark Slates & Neutrals
  static const Color slateDark = Color(0xFF0F172A); // #0F172A
  static const Color slate = Color(0xFF334155); // #334155
  static const Color slateLight = Color(0xFF64748B); // #64748B
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Text Typography
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC); // #F8FAFC
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // #F1F5F9
  static const Color border = Color(0xFFE2E8F0); // #E2E8F0

  // Status & Badges
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);

  // Extended Emerald Palette
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color emerald900 = Color(0xFF064E3B);

  // Extended Amber Palette
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber800 = Color(0xFF92400E);
  static const Color amber900 = Color(0xFF78350F);

  // Extended Rose Palette
  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose700 = Color(0xFFBE123C);

  // Status Aliases
  static const Color emerald = success;
  static const Color emeraldLight = successBg;
  static const Color amber = warning;
  static const Color amberLight = warningBg;
  static const Color rose = error;
  static const Color roseLight = errorBg;
}
