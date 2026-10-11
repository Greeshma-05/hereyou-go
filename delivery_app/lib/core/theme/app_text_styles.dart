import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.9,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.55),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, height: 1.5),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    ),
  );

  static const wordmark = TextStyle(
    color: AppColors.forest,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );
}
