import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Horizontally scrolling row of ChoiceChip filters. Fill, outline and label
/// colour are set here for each state (not left to the theme default), so an
/// unselected label can never end up the same colour as its background.
///
/// When [selected] changes, the selected chip is scrolled into view once the
/// frame is laid out, so a filter set from elsewhere is never hidden off
/// screen. Change [revealRequest] to scroll the selected chip into view again
/// without changing the selection.
class FilterChipRow extends StatefulWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  final int? revealRequest;

  const FilterChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.revealRequest,
  });

  @override
  State<FilterChipRow> createState() => _FilterChipRowState();
}

class _FilterChipRowState extends State<FilterChipRow> {
  // One key per chip, to find the selected chip for scrolling.
  final Map<String, GlobalKey> _chipKeys = {};

  @override
  void didUpdateWidget(FilterChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.revealRequest != widget.revealRequest) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    final label = widget.selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chipContext = _chipKeys[label]?.currentContext;
      if (!mounted || chipContext == null || !chipContext.mounted) return;
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          for (var i = 0; i < widget.labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s2),
            _chip(widget.labels[i]),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) {
    final isSelected = label == widget.selected;
    return ChoiceChip(
      key: _chipKeys.putIfAbsent(label, GlobalKey.new),
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
      onSelected: (_) => widget.onSelected(label),
    );
  }
}
