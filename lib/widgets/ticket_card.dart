import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import 'status_badge.dart';

/// One ticket in a list: id and status on top, title, up to two lines of
/// description (optional), then a date and an action hint. The whole card is
/// tappable.
class TicketCard extends StatelessWidget {
  final String id;
  final String title;

  /// Shown under the title. When null or empty the description and its
  /// spacing are left out.
  final String? description;

  /// The stored status, for example `ASSIGNED`.
  final String status;
  final String dateText;
  final VoidCallback? onTap;
  final String actionLabel;

  const TicketCard({
    super.key,
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.dateText,
    this.onTap,
    this.actionLabel = 'View Details',
  });

  bool get _isCancelled => status.trim().toUpperCase() == 'CANCELLED';

  @override
  Widget build(BuildContext context) {
    final titleStyle = _isCancelled
        ? AppText.heading.copyWith(
            color: AppColors.inkFaint,
            decoration: TextDecoration.lineThrough,
          )
        : AppText.heading.copyWith(color: AppColors.ink);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(title, style: titleStyle),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: AppColors.inkMuted),
                  ),
                ],
                const SizedBox(height: AppSpacing.s3),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.inkFaint,
                      ),
                      const SizedBox(width: AppSpacing.s1),
                      Expanded(
                        child: Text(
                          dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        actionLabel,
                        style: AppText.bodyStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
