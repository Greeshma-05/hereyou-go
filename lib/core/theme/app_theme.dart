import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/accessibility_settings.dart';
import 'app_palette.dart';

class AppTheme {
  static AppPalette colors(BuildContext context) =>
      Theme.of(context).extension<AppAppearance>()?.colors ?? AppPalette.lime;
  static bool readingFont(BuildContext context) =>
      Theme.of(context).extension<AppAppearance>()?.readingFont ?? false;

  static ThemeData get dark => build();

  static ThemeData build({
    AppColorTheme colorTheme = AppColorTheme.lime,
    bool readingFont = false,
  }) {
    final palette = AppPalette.forTheme(colorTheme);
    final green = palette.accent;
    final onAccent = palette.onAccent;
    final ink = palette.ink;
    final muted = palette.muted;
    final canvas = palette.canvas;
    final surface = palette.surface;
    final elevated = palette.elevated;
    final mint = palette.tint;
    final border = palette.border;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: green,
          brightness: Brightness.dark,
        ).copyWith(
          primary: green,
          onPrimary: onAccent,
          secondary: green,
          onSecondary: onAccent,
          primaryContainer: mint,
          onPrimaryContainer: green,
          secondaryContainer: mint,
          onSecondaryContainer: green,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: border,
          outlineVariant: border,
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: readingFont ? 'OpenDyslexic' : null,
      extensions: [
        AppAppearance(colorTheme: colorTheme, readingFont: readingFont),
      ],
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme:
          TextTheme(
            headlineLarge: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: readingFont ? 1.5 : 1.12,
              letterSpacing: readingFont ? .3 : -1.3,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: readingFont ? 1.5 : 1.2,
              letterSpacing: readingFont ? .3 : -.9,
            ),
            titleLarge: TextStyle(
              fontSize: 21,
              height: readingFont ? 1.5 : null,
              fontWeight: FontWeight.w600,
              letterSpacing: readingFont ? .3 : -.5,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              height: readingFont ? 1.5 : null,
              fontWeight: FontWeight.w600,
              letterSpacing: readingFont ? .3 : -.25,
            ),
            bodyLarge: TextStyle(fontSize: 16, height: 1.5),
            bodyMedium: TextStyle(fontSize: 14, height: 1.5),
            bodySmall: TextStyle(fontSize: 12, height: 1.5, color: muted),
            labelLarge: TextStyle(
              fontSize: 14,
              height: readingFont ? 1.5 : null,
              fontWeight: FontWeight.w700,
            ),
          ).apply(
            fontFamily: readingFont ? 'OpenDyslexic' : null,
            bodyColor: ink,
            displayColor: ink,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: green, width: 1.5),
        ),
        hintStyle: TextStyle(color: muted, fontSize: 13),
        prefixIconColor: muted,
        suffixIconColor: green,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(48, 52),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(48, 50),
          foregroundColor: ink,
          side: BorderSide(color: border),
          shape: rounded,
        ),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: green, textColor: onAccent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onAccent : ink,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? green : surface,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: green,
        checkmarkColor: onAccent,
        side: BorderSide(color: border),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: rounded),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
