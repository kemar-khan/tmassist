import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import 'status_style.dart';

/// Pill showing a ticket status in its tinted colours.
class StatusBadge extends StatelessWidget {
  /// The stored status, for example `IN_PROGRESS`.
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        style.label,
        style: AppText.caption.copyWith(
          color: style.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
