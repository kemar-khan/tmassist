import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A rounded box with a dashed outline around [child], for drop zones and
/// signature pads. The child is clipped to the rounded shape.
class DashedBorderBox extends StatelessWidget {
  final Widget child;

  /// Fill behind the child.
  final Color backgroundColor;
  final Color borderColor;
  final BorderRadius? borderRadius;

  const DashedBorderBox({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.surfaceCard,
    this.borderColor = AppColors.borderStrong,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.brMd;

    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: borderColor,
        radius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(color: backgroundColor, child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  static const double _strokeWidth = 1.5;
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final outline = Path()
      ..addRRect(
        radius.toRRect(
          Rect.fromLTWH(
            0,
            0,
            size.width,
            size.height,
          ).deflate(_strokeWidth / 2),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
