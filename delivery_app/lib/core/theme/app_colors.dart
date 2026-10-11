import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF080906);
  static const secondaryBackground = Color(0xFF11130D);
  static const surface = Color(0xFF191B14);
  static const lime = Color(0xFFD9FF43);
  static const secondaryLime = Color(0xFFB9DB36);
  // Existing components share these aliases during the visual migration.
  static const forest = secondaryBackground;
  static const emerald = lime;
  static const mint = lime;
  static const ivory = background;

  static const textPrimary = Color(0xFFF7F8F1);
  static const textSecondary = Color(0xFFA3A697);
  static const textDisabled = Color(0xFF858A78);
  static const outline = Color(0xFF32362A);
  static const outlineStrong = Color(0xFF737A61);
  static const mintTint = Color(0xFF272F16);
  static const neutralTint = Color(0xFF24271D);

  static const amber = Color(0xFFF2B544);
  static const warningText = Color(0xFFFFD887);
  static const warningTint = Color(0xFF382B14);
  static const error = Color(0xFFFFA4A4);
  static const errorTint = Color(0xFF3B2020);
}
