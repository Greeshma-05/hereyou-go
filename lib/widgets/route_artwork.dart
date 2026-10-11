import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_palette.dart';

/// Decorative city illustration; real vendor locations are shown in Explore.
class RouteArtwork extends StatelessWidget {
  const RouteArtwork({super.key, this.height = 210});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _CityPainter(AppTheme.colors(context))),
    ),
  );
}

class _CityPainter extends CustomPainter {
  _CityPainter(this.colors);
  final AppPalette colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(.6, -.3),
          radius: 1.1,
          colors: [colors.tint, colors.canvas],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRect(rect);
    final random = math.Random(24);
    // An isometric city with streets between rows of buildings.
    for (var row = -2; row < 12; row++) {
      for (var col = -3; col < 16; col++) {
        final x = col * 34.0 + (row.isOdd ? 15 : 0);
        final y = row * 27.0 - col * 5;
        final height = 8 + random.nextDouble() * 28;
        final top = Path()
          ..moveTo(x, y)
          ..lineTo(x + 19, y - 7)
          ..lineTo(x + 31, y)
          ..lineTo(x + 12, y + 7)
          ..close();
        canvas.drawPath(
          top,
          Paint()
            ..color = Color.lerp(
              colors.elevated,
              colors.muted,
              random.nextDouble(),
            )!,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + 12, y + 7)
            ..lineTo(x + 12, y + height)
            ..lineTo(x, y + height - 7)
            ..close(),
          Paint()..color = colors.surface,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x + 12, y + 7)
            ..lineTo(x + 31, y)
            ..lineTo(x + 31, y + height - 7)
            ..lineTo(x + 12, y + height)
            ..close(),
          Paint()..color = colors.tint,
        );
      }
    }
    final route = Path()
      ..moveTo(size.width * .10, size.height * .85)
      ..cubicTo(
        size.width * .2,
        size.height * .5,
        size.width * .65,
        size.height * .9,
        size.width * .58,
        size.height * .42,
      )
      ..cubicTo(
        size.width * .55,
        size.height * .17,
        size.width * .86,
        size.height * .3,
        size.width * .9,
        size.height * .1,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = colors.accent.withValues(alpha: .14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = colors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    for (final p in [
      Offset(size.width * .1, size.height * .85),
      Offset(size.width * .58, size.height * .42),
      Offset(size.width * .9, size.height * .1),
    ]) {
      canvas.drawCircle(p, 11, Paint()..color = colors.canvas);
      canvas.drawCircle(p, 7, Paint()..color = colors.accent);
      canvas.drawCircle(p, 3, Paint()..color = colors.onAccent);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, colors.canvas.withValues(alpha: .8)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
