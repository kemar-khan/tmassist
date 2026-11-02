import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Modal bottom sheet with a title, a close button and a list of options.
/// Returns the chosen option, or null if the sheet is dismissed.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  T? selected,
  IconData? Function(T option)? iconBuilder,
  String Function(T option)? labelBuilder,
}) {
  String labelOf(T option) =>
      labelBuilder != null ? labelBuilder(option) : option.toString();

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.s4,
                right: AppSpacing.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.heading.copyWith(color: AppColors.ink),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.s4),
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.s1),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  final icon = iconBuilder?.call(option);

                  return Material(
                    color: isSelected
                        ? AppColors.primaryTint
                        : Colors.transparent,
                    borderRadius: AppRadius.brMd,
                    child: InkWell(
                      borderRadius: AppRadius.brMd,
                      onTap: () => Navigator.pop(sheetContext, option),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s3,
                          ),
                          child: Row(
                            children: [
                              if (icon != null) ...[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    // White on the selected row, so the circle
                                    // stays visible against the tinted row.
                                    color: isSelected
                                        ? AppColors.surfaceCard
                                        : AppColors.primaryTint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s3),
                              ],
                              Expanded(
                                child: Text(
                                  labelOf(option),
                                  style: isSelected
                                      ? AppText.bodyStrong.copyWith(
                                          color: AppColors.primary,
                                        )
                                      : AppText.body.copyWith(
                                          color: AppColors.ink,
                                        ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Looks like [AppTextField] (label above, same outline) but opens a picker
/// when tapped instead of taking text. Pair it with [showPickerSheet].
class AppPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String? hint;
  final IconData? prefixIcon;
  final VoidCallback? onTap;
  final String? errorText;

  const AppPickerField({
    super.key,
    required this.label,
    this.value,
    this.hint,
    this.prefixIcon,
    this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.s1),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            borderRadius: AppRadius.brMd,
            onTap: onTap,
            child: InputDecorator(
              isEmpty: false,
              decoration: InputDecoration(
                errorText: errorText,
                prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
                suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              child: Text(
                hasValue ? value! : (hint ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: hasValue ? AppColors.ink : AppColors.inkFaint,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
