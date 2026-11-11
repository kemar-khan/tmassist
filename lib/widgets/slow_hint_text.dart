import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A small line shown under a loading button when a slow call is still
/// running.
class SlowHintText extends StatelessWidget {
  const SlowHintText({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: Text(
        'Still working… this can take a moment.',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}
