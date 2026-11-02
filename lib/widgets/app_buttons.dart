import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Extra button styles that the theme does not cover.
class AppButtonStyles {
  AppButtonStyles._();

  /// Red outlined button for destructive actions such as Cancel Ticket and
  /// Log Out. Use with [OutlinedButton].
  static ButtonStyle get destructive => OutlinedButton.styleFrom(
    foregroundColor: AppColors.cancelledFg,
    side: const BorderSide(color: AppColors.cancelledFg, width: 2),
    minimumSize: const Size(64, 48),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
    textStyle: AppText.bodyStrong,
  );
}
