import 'package:flutter/material.dart';

/// Single source of truth for how a CANCELLED ticket looks, so the badge is
/// identical in the customer, technician and supervisor screens and clearly
/// different from CLOSED (grey).
class CancelledStatus {
  static const String value = 'CANCELLED';
  static const String label = 'Cancelled';

  static Color get textColor => Colors.red.shade700;
  static Color get backgroundColor => Colors.red.shade50;

  static bool isCancelled(Object? status) =>
      status?.toString().toUpperCase() == value;

  /// Applies a strikethrough (and mutes the colour) to a list-view title when
  /// the ticket is cancelled; returns [base] untouched otherwise.
  static TextStyle titleStyle(TextStyle base, Object? status) {
    if (!isCancelled(status)) return base;
    return base.copyWith(
      decoration: TextDecoration.lineThrough,
      color: Colors.grey[500],
    );
  }
}
