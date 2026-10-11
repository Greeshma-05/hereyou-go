import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/core/theme/app_palette.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/models/accessibility_settings.dart';
import 'package:route_rescue/providers/accessibility_provider.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/widgets/accessibility_button.dart';
import 'support/demo_flow.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('OpenDyslexic')
      ..addFont(rootBundle.load('assets/fonts/OpenDyslexic-Regular.otf'))
      ..addFont(rootBundle.load('assets/fonts/OpenDyslexic-Bold.otf'));
    await loader.load();
  });

  test(
    'all palettes provide readable text, accents and control boundaries',
    () {
      for (final theme in AppColorTheme.values) {
        final p = AppPalette.forTheme(theme);
        for (final background in [p.canvas, p.surface, p.elevated, p.tint]) {
          for (final foreground in [p.ink, p.muted, p.accent]) {
            expect(
              contrast(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '$theme text',
            );
          }
        }
        expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
        expect(
          contrast(p.warning, p.warningSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(p.border, p.surface), greaterThanOrEqualTo(3));
      }
    },
  );

  test(
    'choices persist in order and reset without changing other preferences',
    () async {
      SharedPreferences.setMockInitialValues({'notifications': true});
      final storage = await SharedPreferences.getInstance();
      final settings = AccessibilityProvider(storage);
      await Future.wait([
        settings.setReadingFont(true),
        settings.setColorTheme(AppColorTheme.blueAmber),
        settings.setReadingSize(ReadingSize.extraLarge),
        settings.setColorTheme(AppColorTheme.highContrast),
      ]);
      final restored = AccessibilityProvider(storage);
      expect(restored.readingFont, isTrue);
      expect(restored.colorTheme, AppColorTheme.highContrast);
      expect(restored.readingSize, ReadingSize.extraLarge);
      await restored.reset();
      final reset = AccessibilityProvider(storage);
      expect(reset.readingFont, isFalse);
      expect(reset.colorTheme, AppColorTheme.lime);
      expect(reset.readingSize, ReadingSize.standard);
      expect(storage.getBool('notifications'), isTrue);
      settings.dispose();
      restored.dispose();
      reset.dispose();
    },
  );

  test(
    'invalid storage falls back and missing storage keeps choices usable',
    () async {
      SharedPreferences.setMockInitialValues({
        AccessibilityProvider.storageKey: '{bad',
      });
      final settings = AccessibilityProvider(
        await SharedPreferences.getInstance(),
      );
      expect(settings.readingFont, isFalse);
      expect(settings.colorTheme, AppColorTheme.lime);
      final temporary = AccessibilityProvider(null);
      await temporary.setReadingFont(true);
      expect(temporary.readingFont, isTrue);
      expect(temporary.error, contains('session only'));
      settings.dispose();
      temporary.dispose();
    },
  );

  testWidgets(
    'home settings apply immediately to routes, preserve the cart, and survive restart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = await SharedPreferences.getInstance();
      await tester.pumpWidget(RouteRescueApp(preferences: storage));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Get Started'));
      await tapVisible(tester, find.text('Continue as guest'));
      final settingsButton = find.byTooltip('Reading & appearance');
      final cartButton = find.byTooltip('Open cart');
      expect(
        tester.getCenter(settingsButton).dy,
        tester.getCenter(cartButton).dy,
      );
      expect(
        tester.getCenter(settingsButton).dx,
        lessThan(tester.getCenter(cartButton).dx),
      );
      final cart = tester.element(settingsButton).read<CartProvider>();
      cart.add('meal');
      final originalCount = cart.count;
      expect(originalCount, 1);
      await tapVisible(tester, settingsButton);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reading-font-toggle')),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('colour-theme-blueAmber')),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reading-size-extraLarge')),
      );
      final preview = tester.element(
        find.byKey(const ValueKey('reading-preview')),
      );
      expect(
        Theme.of(preview).textTheme.bodyMedium?.fontFamily,
        'OpenDyslexic',
      );
      expect(AppTheme.colors(preview).accent, AppPalette.blueAmber.accent);
      expect(MediaQuery.textScalerOf(preview).scale(20), 26);
      await tapVisible(tester, find.text('Done'));
      expect(tester.element(settingsButton).read<CartProvider>(), same(cart));
      expect(cart.count, originalCount);
      await tapVisible(tester, cartButton);
      expect(
        AppTheme.colors(tester.element(find.byType(AppBar))).accent,
        AppPalette.blueAmber.accent,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, settingsButton);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('colour-theme-highContrast')),
      );
      await tapVisible(tester, find.text('Done'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RouteRescueApp(preferences: storage));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Get Started'));
      expect(AppTheme.colors(context).accent, AppPalette.highContrast.accent);
      expect(
        Theme.of(context).textTheme.bodyMedium?.fontFamily,
        'OpenDyslexic',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reading font and combined larger text support a complete narrow-screen checkout',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await runDemoFlow(
        tester,
        initialPreferences: {
          AccessibilityProvider.storageKey: jsonEncode({
            'readingFont': true,
            'colorTheme': 'blueAmber',
            'readingSize': 'extraLarge',
          }),
        },
      );
      await tapVisible(tester, find.byType(AccessibilityButton));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('colour-theme-highContrast')),
      );
      await tapVisible(tester, find.text('Restore defaults'));
      await tapVisible(tester, find.text('Done'));
      expect(tester.takeException(), isNull);
    },
  );
}
