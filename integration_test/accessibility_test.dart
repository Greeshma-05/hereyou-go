import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/core/theme/app_palette.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import '../test/support/demo_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    // Let Android finish rasterizing the last animation frame before capturing.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await binding.takeScreenshot(name);
  }

  testWidgets('Android reading options, palettes and navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      RouteRescueApp(preferences: await SharedPreferences.getInstance()),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Get Started'));
    await tapVisible(tester, find.text('Continue as guest'));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await capture(tester, 'accessibility-home-original');
    await tapVisible(tester, find.byTooltip('Reading & appearance'));
    await tapVisible(tester, find.byKey(const ValueKey('reading-font-toggle')));
    await tapVisible(
      tester,
      find.byKey(const ValueKey('colour-theme-blueAmber')),
    );
    await tapVisible(tester, find.byKey(const ValueKey('reading-size-large')));
    final sheetScroll = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(sheetScroll, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await capture(tester, 'accessibility-reading-options');
    await tapVisible(tester, find.text('Done'));
    await capture(tester, 'accessibility-home-blue');
    await tapVisible(tester, find.byTooltip('Open cart'));
    expect(
      AppTheme.colors(tester.element(find.byType(AppBar))).accent,
      AppPalette.blueAmber.accent,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Reading & appearance'));
    await tapVisible(
      tester,
      find.byKey(const ValueKey('colour-theme-highContrast')),
    );
    await capture(tester, 'accessibility-contrast-options');
    await tapVisible(tester, find.text('Done'));
    await capture(tester, 'accessibility-home-contrast');
    await tapVisible(tester, find.byTooltip('Reading & appearance'));
    await tapVisible(tester, find.text('Restore defaults'));
    await tapVisible(tester, find.text('Done'));
    expect(tester.takeException(), isNull);
  });
}
