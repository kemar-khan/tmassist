import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// White card with an optional title row. Replaces the per-screen `_buildCard`
/// and `_buildSectionTitle` helpers.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: AppText.heading.copyWith(color: AppColors.ink),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          child,
        ],
      ),
    );
  }
}
