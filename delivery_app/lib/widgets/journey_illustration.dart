import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

enum JourneyScene { delivery, shopRoute, map, verified }

class JourneyIllustration extends StatelessWidget {
  const JourneyIllustration({
    this.scene = JourneyScene.delivery,
    this.progress = 1,
    this.onDark = false,
    super.key,
  });

  final JourneyScene scene;
  final double progress;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (scene != JourneyScene.delivery) {
      return ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: ColoredBox(
              color: onDark ? AppColors.forest : AppColors.mintTint,
              child: CustomPaint(
                painter: _MapPainter(
                  scene: scene,
                  progress: progress,
                  onDark: onDark,
                ),
                child: scene == JourneyScene.verified
                    ? Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const _WaypointIcon(
                              icon: Icons.inventory_2_outlined,
                              large: true,
                            ),
                            Positioned(
                              right: -12,
                              bottom: -12,
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.surface,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          Align(
                            alignment: const Alignment(-0.72, 0.48),
                            child: _WaypointIcon(
                              icon: scene == JourneyScene.map
                                  ? Icons.my_location_rounded
                                  : Icons.storefront_outlined,
                            ),
                          ),
                          Align(
                            alignment: const Alignment(0.72, -0.48),
                            child: _WaypointIcon(
                              icon: scene == JourneyScene.map
                                  ? Icons.location_on_outlined
                                  : Icons.luggage_outlined,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: 88,
        width: double.infinity,
        child: CustomPaint(
          painter: const _JourneyRoutePainter(),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.mintTint,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.lime,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaypointIcon extends StatelessWidget {
  const _WaypointIcon({required this.icon, this.large = false});

  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 100 : 56,
      height: large ? 100 : 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.lime, size: large ? 52 : 28),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.scene,
    required this.progress,
    required this.onDark,
  });

  final JourneyScene scene;
  final double progress;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 200);
    final roadPaint = Paint()
      ..color = (onDark ? AppColors.mint : AppColors.forest).withValues(
        alpha: 0.08,
      )
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    final roads = Path()
      ..moveTo(-20, 30)
      ..lineTo(320, 170)
      ..moveTo(80, -20)
      ..lineTo(180, 220)
      ..moveTo(230, -20)
      ..lineTo(130, 220);
    canvas.drawPath(roads, roadPaint);

    final route = Path()
      ..moveTo(52, 140)
      ..lineTo(126, 140)
      ..cubicTo(190, 140, 112, 60, 182, 60)
      ..lineTo(248, 60);
    final routePaint = Paint()
      ..color = onDark ? AppColors.mint : AppColors.emerald
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in route.computeMetrics()) {
      final visibleLength = metric.length * progress.clamp(0.0, 1.0);
      for (var distance = 0.0; distance < visibleLength; distance += 10) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + 4).clamp(0.0, visibleLength),
          ),
          routePaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.scene != scene ||
      oldDelegate.onDark != onDark;
}

class _JourneyRoutePainter extends CustomPainter {
  const _JourneyRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final end = Offset(size.width - 12, 24);
    final route = Path()
      ..moveTo(80, 60)
      ..lineTo(size.width * 0.52, 60)
      ..cubicTo(
        size.width * 0.7,
        60,
        size.width * 0.57,
        24,
        size.width * 0.76,
        24,
      )
      ..lineTo(end.dx, end.dy);
    final linePaint = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final metric in route.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(metric.extractPath(distance, distance + 3), linePaint);
      }
    }

    canvas.drawCircle(end, 10, Paint()..color = AppColors.mint);
    canvas.drawCircle(end, 4, Paint()..color = AppColors.forest);
  }

  @override
  bool shouldRepaint(_JourneyRoutePainter oldDelegate) => false;
}
