import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for TMAssist. Screens must use these (or the theme and the
/// shared widgets in lib/widgets) instead of hard-coding colours, sizes,
/// radii or spacing.
class AppColors {
  AppColors._();

  static const primary = Color(
    0xFF005CAB,
  ); // brand blue: headers, links, selected states
  static const primaryDark = Color(0xFF00457F); // pressed state, darker band
  static const primaryTint = Color(
    0xFFE6F0FA,
  ); // light blue fill, nav indicator
  static const accent = Color(
    0xFFFF6600,
  ); // brand orange: large fills and icons only, NEVER behind white text
  static const accentStrong = Color(
    0xFFC94F00,
  ); // orange used behind white text (buttons, CTA card)
  static const accentTint = Color(0xFFFFF0E6);
  static const surfaceBg = Color(0xFFF5F7FA); // page background
  static const surfaceCard = Color(0xFFFFFFFF); // cards, inputs, nav bar
  static const border = Color(0xFFE3E8EF); // hairlines, dividers
  static const borderStrong = Color(0xFF7F8EA3); // input and chip outlines
  static const ink = Color(0xFF1A2433); // primary text
  static const inkMuted = Color(0xFF475569); // secondary text
  static const inkFaint = Color(0xFF5E6E85); // captions, hints, inactive icons
  static const onPrimary = Color(0xFFFFFFFF);

  // Status pairs (text colour, background)
  static const newFg = Color(0xFF92400E);
  static const newBg = Color(0xFFFEF3C7);
  static const assignedFg = Color(0xFF005CAB);
  static const assignedBg = Color(0xFFE6F0FA);
  static const progressFg = Color(0xFF6D28D9);
  static const progressBg = Color(0xFFEDE9FE);
  static const resolvedFg = Color(0xFF166534);
  static const resolvedBg = Color(0xFFDCFCE7);
  static const closedFg = Color(0xFF475569);
  static const closedBg = Color(0xFFE2E8F0);
  static const cancelledFg = Color(0xFFB91C1C);
  static const cancelledBg = Color(0xFFFEE2E2);
}

class AppSpacing {
  AppSpacing._();

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get brSm => BorderRadius.circular(sm);
  static BorderRadius get brMd => BorderRadius.circular(md);
  static BorderRadius get brLg => BorderRadius.circular(lg);
  static BorderRadius get brXl => BorderRadius.circular(xl);
  static BorderRadius get brPill => BorderRadius.circular(pill);

  /// Rounded top corners only (bottom sheets).
  static BorderRadius get topXl =>
      const BorderRadius.vertical(top: Radius.circular(xl));

  /// Rounded bottom corners only (home header).
  static BorderRadius get bottomXl =>
      const BorderRadius.vertical(bottom: Radius.circular(xl));
}

class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x14102440), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const nav = [
    BoxShadow(color: Color(0x1F102440), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

/// The only text sizes in the app (Inter). Colour is not set here so the
/// styles pick it up from the theme; add `.copyWith(color: ...)` where needed.
class AppText {
  AppText._();

  /// 28 / line 34 / w700: large numbers, login title.
  static TextStyle get display => GoogleFonts.inter(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
  );

  /// 20 / line 28 / w700: screen titles, header greeting.
  static TextStyle get title => GoogleFonts.inter(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
  );

  /// 16 / line 24 / w600: section titles, card titles, buttons.
  static TextStyle get heading => GoogleFonts.inter(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// 14 / line 20 / w400: descriptions, form text.
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// 14 / line 20 / w600: links, selected chips.
  static TextStyle get bodyStrong => GoogleFonts.inter(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  /// 12 / line 16 / w500: dates, ids, badges, nav labels.
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
}
