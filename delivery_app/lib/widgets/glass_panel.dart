import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .87),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: .12),
          ),
        ),
        child: child,
      ),
    ),
  );
}
