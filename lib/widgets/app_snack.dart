import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

enum SnackKind { success, error, info }

/// Shows a floating, tinted snackbar: green for success, red for errors and
/// blue for information.
void showAppSnack(
  BuildContext context,
  String message, {
  SnackKind kind = SnackKind.info,
}) {
  final Color bg;
  final Color fg;
  final IconData icon;

  switch (kind) {
    case SnackKind.success:
      bg = AppColors.resolvedBg;
      fg = AppColors.resolvedFg;
      icon = Icons.check_circle_outline;
    case SnackKind.error:
      bg = AppColors.cancelledBg;
      fg = AppColors.cancelledFg;
      icon = Icons.error_outline;
    case SnackKind.info:
      bg = AppColors.primaryTint;
      fg = AppColors.primary;
      icon = Icons.info_outline;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: 0,
      margin: const EdgeInsets.all(AppSpacing.s4),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      content: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(message, style: AppText.bodyStrong.copyWith(color: fg)),
          ),
        ],
      ),
    ),
  );
}
