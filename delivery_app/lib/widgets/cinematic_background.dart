import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class CinematicBackground extends StatelessWidget {
  const CinematicBackground({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 900),
    child: child,
    builder: (context, value, content) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.9, -0.85),
          radius: 1.25,
          colors: [
            Color.lerp(
              AppColors.secondaryBackground,
              const Color(0xFF293019),
              value,
            )!,
            AppColors.background,
          ],
        ),
      ),
      child: content,
    ),
  );
}
