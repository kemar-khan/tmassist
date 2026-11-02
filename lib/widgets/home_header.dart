import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/theme/app_tokens.dart';

/// Blue rounded header for the three home screens.
///
/// The top padding follows the device's status-bar inset. The bottom padding
/// leaves [bottomOverlap] of extra blue, so a card passed as [overlapChild]
/// can sit half on the header and half on the page without any fixed heights
/// and without leaving a gap below the card.
class HomeHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double bottomOverlap;

  /// Optional card that overlaps the bottom edge of the header by
  /// [bottomOverlap].
  final Widget? overlapChild;

  const HomeHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottomOverlap = 56,
    this.overlapChild,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    final header = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.bottomXl,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s4,
        topInset + AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4 + bottomOverlap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title.copyWith(color: AppColors.onPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    subtitle!,
                    style: AppText.body.copyWith(color: AppColors.primaryTint),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.s2),
            trailing!,
          ],
        ],
      ),
    );

    if (overlapChild == null) return header;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        _PullUp(
          amount: bottomOverlap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: overlapChild,
          ),
        ),
      ],
    );
  }
}

/// Pulls [child] up by [amount] so it overlaps the widget above it (a header),
/// without leaving a gap below. Works like a negative margin.
class HeaderOverlap extends StatelessWidget {
  final double amount;
  final Widget child;

  const HeaderOverlap({super.key, required this.amount, required this.child});

  @override
  Widget build(BuildContext context) => _PullUp(amount: amount, child: child);
}

/// Lays its child out [amount] higher than the normal position and shrinks
/// its own height by the same amount, which works like a negative margin.
class _PullUp extends SingleChildRenderObjectWidget {
  const _PullUp({required this.amount, super.child});

  final double amount;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPullUp(amount);

  @override
  void updateRenderObject(BuildContext context, _RenderPullUp renderObject) {
    renderObject.amount = amount;
  }
}

class _RenderPullUp extends RenderShiftedBox {
  _RenderPullUp(this._amount) : super(null);

  double _amount;

  set amount(double value) {
    if (_amount == value) return;
    _amount = value;
    markNeedsLayout();
  }

  // Report the shortened height to IntrinsicHeight and friends.
  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(0, super.computeMinIntrinsicHeight(width) - _amount);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(0, super.computeMaxIntrinsicHeight(width) - _amount);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final childSize = child.getDryLayout(constraints);
    return constraints.constrain(
      Size(childSize.width, math.max(0, childSize.height - _amount)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, math.max(0, child.size.height - _amount)),
    );
    (child.parentData! as BoxParentData).offset = Offset(0, -_amount);
  }

  // The child sticks out above this box's bounds, so let taps there through.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      hitTestChildren(result, position: position);
}
