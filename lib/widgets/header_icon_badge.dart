import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Decorative round mark at the top right of a home header: an image inside a
/// white circle with a soft white ring. Not tappable and hidden from
/// accessibility. If the image cannot be loaded, a person outline is shown
/// instead.
class HeaderIconBadge extends StatelessWidget {
  /// Asset path of the image, for example `assets/images/customer_icon.png`.
  final String asset;

  const HeaderIconBadge({super.key, required this.asset});

  /// Diameter of the circle and size of the image inside it.
  static const double circleSize = 56;
  static const double imageSize = 40;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: circleSize,
        height: circleSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.onPrimary.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        child: Center(
          child: Image.asset(
            asset,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.person_outline,
              size: imageSize,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
