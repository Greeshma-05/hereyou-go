import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'demo_flow.dart';

const typedDeliveryAddress = '42 Test Road, Kochi';
const typedDeliveryInstructions = 'Meet beside the bakery at the blue gate.';

Future<void> runDeliveryFlow(
  WidgetTester tester, {
  Future<void> Function(String)? capture,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    RouteRescueApp(preferences: await SharedPreferences.getInstance()),
  );
  await tester.pumpAndSettle();
  expect(find.text('Here You Go'), findsOneWidget);
  await tapVisible(tester, find.text('Get Started'));
  await tapVisible(tester, find.text('Continue as guest'));
  expect(find.text('Delivery place'), findsOneWidget);
  await tapVisible(tester, find.text('Where should we meet you?'));
  await tapVisible(tester, find.text('Fill sample journey'));
  await chooseBusRangeDelivery(tester);
  final address = find.byKey(const ValueKey('delivery-place-field'));
  final instructions = find.byKey(
    const ValueKey('delivery-instructions-field'),
  );
  await tester.enterText(address, typedDeliveryAddress);
  await tester.enterText(instructions, typedDeliveryInstructions);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  // Typing a new address must invalidate the old suggested-stop pin.
  await tapVisible(tester, find.text('Save journey'));
  expect(
    find.text('Pin your delivery place on the map, or choose a nearby stop.'),
    findsOneWidget,
  );
  await tapVisible(tester, find.text('Pin delivery location'));
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Use this location'),
        )
        .onPressed,
    isNull,
  );
  final map = find.byKey(const ValueKey('delivery-location-map'));
  await tester.ensureVisible(map);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(map) + const Offset(20, 15));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('delivery-location-pin')), findsOneWidget);
  if (capture != null) await capture('here-you-go-delivery-pin');
  await tapVisible(tester, find.text('Use this location'));
  expect(
    find.text('Map pin confirmed for this delivery place.'),
    findsOneWidget,
  );
  await tester.ensureVisible(address);
  await tester.pumpAndSettle();
  if (capture != null) await capture('here-you-go-delivery-address');
  await tapVisible(tester, find.text('Save journey'));
  expect(find.text(typedDeliveryAddress), findsOneWidget);
  final journey = tester
      .element(find.text(typedDeliveryAddress))
      .read<JourneyProvider>()
      .journey!;
  expect(journey.pickup.id, 'custom-bus');
  expect(journey.pickup.instructions, typedDeliveryInstructions);
  expect(journey.pickup.isValid, isTrue);
  // Reloading a custom address must not select a nonexistent dropdown item.
  await tapVisible(tester, find.byTooltip('Edit journey'));
  expect(
    tester.widget<TextFormField>(address).controller!.text,
    typedDeliveryAddress,
  );
  expect(
    tester.widget<TextFormField>(instructions).controller!.text,
    typedDeliveryInstructions,
  );
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byType(TextField));
  await tapVisible(tester, find.text('The Travellers’ Kitchen'));
  await tapVisible(tester, find.text('Add +'));
  await tapVisible(tester, find.byTooltip('Open cart'));
  await tapVisible(tester, find.text('Continue to checkout'));
  expect(find.text(typedDeliveryAddress), findsOneWidget);
  expect(find.text(typedDeliveryInstructions), findsOneWidget);
  await tapVisible(tester, find.text('Create preview'));
  final order = tester
      .element(find.text('Preview created'))
      .read<OrderProvider>()
      .orders
      .single;
  expect(order.journey.pickup.name, typedDeliveryAddress);
  expect(order.journey.pickup.position, journey.pickup.position);
  expect(order.journey.pickup.instructions, typedDeliveryInstructions);
  expect(order.reference, startsWith('HYG-'));
  expect(tester.takeException(), isNull);
}
