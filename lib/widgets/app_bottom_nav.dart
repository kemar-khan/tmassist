import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// One tab in [AppBottomNav].
class AppNavItem {
  /// Outlined icon, shown when the tab is not selected.
  final IconData icon;

  /// Filled icon, shown when the tab is selected.
  final IconData activeIcon;
  final String label;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Floating bottom navigation: a [NavigationBar] in a rounded, shadowed card
/// that sits 16 from the screen edges and above the bottom safe area. Colours
/// and label styles come from the theme.
class AppBottomNav extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  /// Height of the navigation bar itself.
  static const double barHeight = 80;

  /// Bottom padding that content OUTSIDE the Scaffold body needs so its last
  /// item stays clear of the floating bar: bar height, the bar's own 16 margin
  /// top and bottom, and the device's bottom safe area. Inside the body of a
  /// `Scaffold(extendBody: true)`, `MediaQuery.paddingOf(context).bottom`
  /// already includes all of this, so use that plus a gap instead.
  static double clearance(BuildContext context) =>
      barHeight + AppSpacing.s4 * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: AppRadius.brLg,
            boxShadow: AppShadows.nav,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.brLg,
            child: NavigationBar(
              height: barHeight,
              selectedIndex: currentIndex,
              onDestinationSelected: onTap,
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: item.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
