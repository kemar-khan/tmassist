import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Centred icon, title and subtitle for lists with nothing to show.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional widget under the text, such as a "Try Again" button.
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.heading.copyWith(color: AppColors.ink),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
