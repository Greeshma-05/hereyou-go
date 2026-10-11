import 'package:flutter/material.dart';
import '../../models/accessibility_settings.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.accent,
    required this.onAccent,
    required this.ink,
    required this.muted,
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.tint,
    required this.border,
    required this.warning,
    required this.warningSurface,
  });

  final Color accent, onAccent, ink, muted, canvas, surface, elevated, tint;
  final Color border, warning, warningSurface;

  static AppPalette forTheme(AppColorTheme theme) => switch (theme) {
    AppColorTheme.lime => lime,
    AppColorTheme.blueAmber => blueAmber,
    AppColorTheme.highContrast => highContrast,
  };

  static const lime = AppPalette(
    accent: Color(0xFFD9FF43),
    onAccent: Color(0xFF151B02),
    ink: Color(0xFFF5F7EF),
    muted: Color(0xFFB2B8A9),
    canvas: Color(0xFF090B08),
    surface: Color(0xFF171A14),
    elevated: Color(0xFF22271B),
    tint: Color(0xFF29321A),
    border: Color(0xFF758064),
    warning: Color(0xFFFFD27D),
    warningSurface: Color(0xFF332B17),
  );
  static const blueAmber = AppPalette(
    accent: Color(0xFF8CD9FF),
    onAccent: Color(0xFF062636),
    ink: Color(0xFFF4F8FB),
    muted: Color(0xFFBDCAD5),
    canvas: Color(0xFF081019),
    surface: Color(0xFF101F2C),
    elevated: Color(0xFF1A2D3D),
    tint: Color(0xFF17394F),
    border: Color(0xFF8199AB),
    warning: Color(0xFFFFD27D),
    warningSurface: Color(0xFF382B15),
  );
  static const highContrast = AppPalette(
    accent: Colors.white,
    onAccent: Colors.black,
    ink: Colors.white,
    muted: Color(0xFFE0E0E0),
    canvas: Colors.black,
    surface: Colors.black,
    elevated: Color(0xFF111111),
    tint: Color(0xFF202020),
    border: Color(0xFFBDBDBD),
    warning: Color(0xFFFFE082),
    warningSurface: Color(0xFF242000),
  );
}

class AppAppearance extends ThemeExtension<AppAppearance> {
  const AppAppearance({required this.colorTheme, required this.readingFont});
  final AppColorTheme colorTheme;
  final bool readingFont;
  AppPalette get colors => AppPalette.forTheme(colorTheme);

  @override
  AppAppearance copyWith({AppColorTheme? colorTheme, bool? readingFont}) =>
      AppAppearance(
        colorTheme: colorTheme ?? this.colorTheme,
        readingFont: readingFont ?? this.readingFont,
      );

  @override
  AppAppearance lerp(covariant AppAppearance? other, double t) =>
      other != null && t >= .5 ? other : this;
}
