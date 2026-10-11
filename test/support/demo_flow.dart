import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'package:route_rescue/models/order_model.dart';
import 'range_fixtures.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> chooseBusRangeDelivery(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('delivery-place-field')),
    busRangePickup.name,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Pin delivery location'));
  final map = find.byKey(const ValueKey('delivery-location-map'));
  await tester.ensureVisible(map);
  tester
      .widget<FlutterMap>(map)
      .mapController!
      .move(busRangePickup.position, 16);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(map));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Use this location'));
}

Future<void> runDemoFlow(
  WidgetTester tester, {
  Map<String, Object> initialPreferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  await tester.pumpWidget(
    RouteRescueApp(preferences: await SharedPreferences.getInstance()),
  );
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Get Started'));
  await tapVisible(tester, find.text('Continue as guest'));
  await tapVisible(tester, find.text('Bus journey'));
  await tapVisible(tester, find.text('Fill sample journey'));
  await chooseBusRangeDelivery(tester);
  await tapVisible(tester, find.text('Save journey'));
  expect(find.text('Ernakulam → Thrissur'), findsOneWidget);
  await tapVisible(tester, find.byType(TextField));
  await tapVisible(tester, find.text('The Travellers’ Kitchen'));
  await tapVisible(tester, find.text('Add +'));
  await tapVisible(tester, find.byTooltip('Open cart'));
  expect(find.text('Kerala veg meal'), findsOneWidget);
  expect(find.text('₹170'), findsOneWidget);
  await tapVisible(tester, find.text('Continue to checkout'));
  await tapVisible(tester, find.text('Create preview'));
  expect(find.text('Preview created'), findsOneWidget);
  for (var i = 0; i < 5; i++) {
    await tapVisible(tester, find.text('Next preview stage'));
  }
  expect(find.text('Next preview stage'), findsNothing);
  final context = tester.element(find.text('Preview created'));
  expect(
    context.read<OrderProvider>().orders.single.status,
    OrderStatus.handedOver,
  );
  await tapVisible(tester, find.text('Back to your journey'));
  await tapVisible(tester, find.byTooltip('Orders'));
  expect(find.text('Previews'), findsOneWidget);
  await tapVisible(tester, find.byTooltip('Profile'));
  await tapVisible(tester, find.text('Drinking water'));
  await tapVisible(tester, find.byTooltip('Edit profile'));
  await tester.enterText(find.byType(TextFormField).first, 'Asha Demo');
  await tapVisible(tester, find.text('Save profile'));
  expect(find.text('Asha Demo'), findsOneWidget);
  await tapVisible(tester, find.byTooltip('Home'));
  expect(tester.takeException(), isNull);
}
