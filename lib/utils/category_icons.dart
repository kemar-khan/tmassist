import 'package:flutter/material.dart';

/// The icon for a ticket category: Network, Hardware, Software, and a generic
/// one for anything else.
IconData categoryIcon(String category) {
  switch (category) {
    case 'Network':
      return Icons.wifi_rounded;
    case 'Hardware':
      return Icons.memory;
    case 'Software':
      return Icons.desktop_windows_outlined;
    default:
      return Icons.more_horiz_rounded;
  }
}
