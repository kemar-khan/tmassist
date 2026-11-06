import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Faint decorative outline of a ticket stub and two circles, meant to sit
/// behind the content of a blue header (see `HomeHeader.background`). It is
/// purely decorative and hidden from accessibility.
class TicketStubPattern extends StatelessWidget {
  const TicketStubPattern({super.key});

  /// Size of the drawing area the painter's coordinates refer to.
  static const Size size = Size(200, 160);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(painter: _TicketStubPainter()),
      ),
    );
  }
}

class _TicketStubPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onPrimary.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // (a) The ticket, rotated -14 degrees about (110, 80).
    canvas.save();
    canvas.translate(110, 80);
    canvas.rotate(-14 * math.pi / 180);
    canvas.translate(-110, -80);

    final notch = Radius.circular(10);
    final ticket = Path()
      ..moveTo(40, 50)
      ..lineTo(160, 50)
      ..lineTo(160, 70)
      // Right notch, bulging into the ticket.
      ..arcToPoint(const Offset(160, 90), radius: notch, clockwise: false)
      ..lineTo(160, 110)
      ..lineTo(40, 110)
      ..lineTo(40, 90)
      // Left notch, bulging into the ticket.
      ..arcToPoint(const Offset(40, 70), radius: notch, clockwise: false)
      ..close();
    canvas.drawPath(ticket, paint);

    // Dashed tear line (dash 4, gap 6).
    for (double y = 50; y < 110; y += 10) {
      canvas.drawLine(Offset(118, y), Offset(118, math.min(y + 4, 110)), paint);
    }
    canvas.restore();

    // (b) and (c) The two circles.
    canvas.drawCircle(const Offset(170, 20), 26, paint);
    canvas.drawCircle(const Offset(26, 132), 18, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
