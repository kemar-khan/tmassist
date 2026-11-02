import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Horizontally scrolling row of ChoiceChip filters. Fill, outline and label
/// colour are set here for each state (not left to the theme default), so an
/// unselected label can never end up the same colour as its background.
class FilterChipRow extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s2),
            _chip(labels[i]),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) {
    final isSelected = label == selected;
    return ChoiceChip(
      // Keeps the tappable area at least 44dp high.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      showCheckmark: false,
      label: Text(label),
      labelStyle: AppText.bodyStrong.copyWith(
        color: isSelected ? AppColors.onPrimary : AppColors.inkMuted,
      ),
      backgroundColor: AppColors.surfaceCard,
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.borderStrong,
        width: 1.5,
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(label),
    );
  }
}
