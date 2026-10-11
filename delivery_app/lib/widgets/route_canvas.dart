import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// An offline schematic, not geographic tiles or a navigable road network.
class RouteCanvas extends StatelessWidget {
  const RouteCanvas({this.height = 220, this.showLabels = true, super.key});
  final double height;
  final bool showLabels;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Simulated Bengaluru to Mysuru journey schematic',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _RoutePainter(showLabels)),
      ),
    ),
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.showLabels);
  final bool showLabels;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.secondaryBackground,
    );
    canvas.save();
    canvas.scale(size.width / 600, size.height / 340);
    final block = Paint()..color = const Color(0xFF20261A);
    for (var x = -30.0; x < 660; x += 44) {
      for (var y = -20.0; y < 400; y += 38) {
        final offset = math.sin((x + y) / 65) * 12;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + offset, y, 28, 22),
            const Radius.circular(4),
          ),
          block,
        );
      }
    }
    final road = Paint()
      ..color = const Color(0xFF444A35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(-40, i * 56.0)
          ..cubicTo(180, i * 24.0, 320, i * 60.0 - 40, 660, i * 42.0),
        road,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(70, -20)
        ..cubicTo(20, 90, 160, 210, 85, 380),
      Paint()
        ..color = const Color(0xFF263C31)
        ..strokeWidth = 20
        ..style = PaintingStyle.stroke,
    );
    final route = Path()
      ..moveTo(530, 58)
      ..lineTo(436, 94)
      ..cubicTo(350, 110, 405, 188, 315, 190)
      ..lineTo(258, 190)
      ..cubicTo(188, 195, 245, 272, 158, 282)
      ..lineTo(78, 296);
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.lime.withValues(alpha: .2)
        ..strokeWidth = 18
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.lime
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
    Offset project(Offset point) =>
        Offset(point.dx * size.width / 600, point.dy * size.height / 340);
    for (final point in [
      const Offset(530, 58),
      const Offset(436, 94),
      const Offset(315, 190),
      const Offset(158, 282),
      const Offset(78, 296),
    ]) {
      canvas.drawCircle(
        project(point),
        7,
        Paint()..color = AppColors.background,
      );
      canvas.drawCircle(project(point), 3.5, Paint()..color = AppColors.lime);
    }
    if (showLabels) {
      _label(canvas, 'BENGALURU', project(const Offset(420, 26)));
      _label(canvas, 'BIDADI', project(const Offset(328, 205)));
      _label(canvas, 'MYSURU', project(const Offset(52, 266)));
    }
  }

  void _label(Canvas canvas, String label, Offset offset) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      showLabels != oldDelegate.showLabels;
}
