import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/providers/location_provider.dart';
import 'package:route_rescue/screens/explore/explore_screen.dart';
import 'package:route_rescue/widgets/vendor_card.dart';
import 'support/demo_flow.dart';
import 'support/range_fixtures.dart';
import 'state_test.dart' show sampleJourney;

void main() {
  testWidgets(
    'customer completes the demo journey, checkout, tracking and profile flow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runDemoFlow(tester);
    },
  );
  testWidgets('sign-up validates empty and malformed fields', (tester) async {
    await tester.pumpWidget(const RouteRescueApp());
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Get Started'));
    await tapVisible(tester, find.text('Sign up'));
    await tapVisible(tester, find.text('Create profile'));
    expect(find.text('Please complete this field.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('local search shows and clears an empty result', (tester) async {
    final journey = JourneyProvider();
    await journey.save(sampleJourney(pickup: busRangePickup));
    addTearDown(journey.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider.value(value: journey),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ExploreScreen(initialMap: false),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'unfindable-item');
    await tester.pumpAndSettle();
    expect(find.text('Nothing here just yet'), findsOneWidget);
    await tapVisible(tester, find.text('Clear filters'));
    expect(find.text('Nothing here just yet'), findsNothing);
    expect(find.text('The Travellers’ Kitchen'), findsWidgets);
  });
  testWidgets(
    'supply search shows stock matches and does not promote sold-out medicine',
    (tester) async {
      final journey = JourneyProvider();
      await journey.save(sampleJourney(pickup: busRangePickup));
      addTearDown(journey.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider.value(value: journey),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const ExploreScreen(initialMap: false),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ORS');
      await tester.pumpAndSettle();
      expect(
        tester.widget<VendorCard>(find.byType(VendorCard)).highlight,
        isTrue,
      );
      expect(find.textContaining('1 matching item in stock'), findsOneWidget);
      expect(find.text('Oral rehydration salts'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'saline');
      await tester.pumpAndSettle();
      expect(
        tester.widget<VendorCard>(find.byType(VendorCard)).highlight,
        isFalse,
      );
      expect(find.text('Matching items are out of stock'), findsOneWidget);
      expect(
        find.textContaining('No matching supplies are available'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('onboarding remains usable on a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const RouteRescueApp());
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Get Started'));
    expect(find.text('Welcome aboard.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'train handover, profile preferences and logout remain navigable',
    (tester) async {
      await tester.pumpWidget(const RouteRescueApp());
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Get Started'));
      await tapVisible(tester, find.text('Continue as guest'));
      await tapVisible(tester, find.text('Train journey'));
      await tapVisible(tester, find.text('Fill sample journey'));
      expect(find.text('Train number or name'), findsOneWidget);
      await tapVisible(tester, find.text('Save journey'));
      expect(find.text('Ernakulam Junction'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Profile'));
      await tapVisible(tester, find.text('Journey notifications'));
      expect(
        find.textContaining('Preferences are available for this session only.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Help & support'));
      await tapVisible(tester, find.text('How does Here You Go work?'));
      expect(
        find.textContaining('Guest checkout remains a preview.'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Log out'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Log out'));
      expect(find.text('Welcome aboard.'), findsOneWidget);
    },
  );
}
