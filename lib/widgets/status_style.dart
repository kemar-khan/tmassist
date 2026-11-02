import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Label and colour pair for a ticket status.
class StatusStyle {
  final String label;
  final Color fg;
  final Color bg;

  const StatusStyle({required this.label, required this.fg, required this.bg});
}

/// Maps a stored status (NEW, ASSIGNED, IN_PROGRESS, RESOLVED, CLOSED,
/// CANCELLED) to its label and colours. Unknown values use the Closed colours
/// and show the raw text.
StatusStyle statusStyle(String rawStatus) {
  switch (rawStatus.trim().toUpperCase()) {
    case 'NEW':
      return const StatusStyle(
        label: 'New',
        fg: AppColors.newFg,
        bg: AppColors.newBg,
      );
    case 'ASSIGNED':
      return const StatusStyle(
        label: 'Assigned',
        fg: AppColors.assignedFg,
        bg: AppColors.assignedBg,
      );
    case 'IN_PROGRESS':
      return const StatusStyle(
        label: 'In Progress',
        fg: AppColors.progressFg,
        bg: AppColors.progressBg,
      );
    case 'RESOLVED':
      return const StatusStyle(
        label: 'Resolved',
        fg: AppColors.resolvedFg,
        bg: AppColors.resolvedBg,
      );
    case 'CLOSED':
      return const StatusStyle(
        label: 'Closed',
        fg: AppColors.closedFg,
        bg: AppColors.closedBg,
      );
    case 'CANCELLED':
      return const StatusStyle(
        label: 'Cancelled',
        fg: AppColors.cancelledFg,
        bg: AppColors.cancelledBg,
      );
    default:
      return StatusStyle(
        label: rawStatus,
        fg: AppColors.closedFg,
        bg: AppColors.closedBg,
      );
  }
}
