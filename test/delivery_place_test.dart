import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/firebase/cloud_serialization.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/services/mock_order_service.dart';
import 'support/delivery_flow.dart';

Journey customJourney(PickupStop place) => Journey(
  mode: JourneyMode.bus,
  operatorName: 'Bus 101',
  boarding: 'Kochi',
  destination: 'Thrissur',
  departure: DateTime.now().add(const Duration(hours: 2)),
  pickup: place,
);

void main() {
  test(
    'custom address and coordinates round-trip through order and history documents',
    () {
      final place = PickupStop.custom(
        mode: JourneyMode.bus,
        name: typedDeliveryAddress,
        position: const LatLng(9.99, 76.29),
        instructions: typedDeliveryInstructions,
      );
      final journey = customJourney(place);
      final restored = CloudSerialization.readJourney(
        CloudSerialization.journey(journey),
      );
      expect(restored.pickup.name, typedDeliveryAddress);
      expect(restored.pickup.position, place.position);
      expect(restored.pickup.instructions, typedDeliveryInstructions);
      final order = MockOrderService().create(
        items: [CartItem(Catalog.product('meal'), 1)],
        journey: restored,
      );
      final saved = CloudSerialization.readOrder(
        CloudSerialization.order(order),
      );
      expect(saved.journey.pickup.name, typedDeliveryAddress);
      expect(saved.journey.pickup.instructions, typedDeliveryInstructions);
      expect(saved.journey.pickup.position, place.position);
    },
  );
  test(
    'custom delivery rejects empty addresses, invalid coordinates and wrong travel mode',
    () {
      final invalid = [
        PickupStop('custom-bus', ' ', const LatLng(9, 76), 'Meet here'),
        PickupStop('custom-bus', 'House', const LatLng(9, 76), ''),
        PickupStop('custom-bus', 'x' * 161, const LatLng(9, 76), 'Meet here'),
        PickupStop('custom-bus', 'House', LatLng(double.nan, 76), 'Meet here'),
        PickupStop('custom-bus', 'House', const LatLng(9, 181), 'Meet here'),
      ];
      for (final place in invalid) {
        expect(customJourney(place).isValid, isFalse);
        expect(
          () => MockOrderService().create(
            items: [CartItem(Catalog.product('meal'), 1)],
            journey: customJourney(place),
          ),
          throwsStateError,
        );
      }
      final wrongMode = PickupStop.custom(
        mode: JourneyMode.train,
        name: 'House',
        position: const LatLng(9, 76),
        instructions: 'Meet here',
      );
      expect(
        () => MockOrderService().create(
          items: [CartItem(Catalog.product('meal'), 1)],
          journey: customJourney(wrongMode),
        ),
        throwsStateError,
      );
    },
  );
  testWidgets(
    'typed address and selected map pin survive editing and checkout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runDeliveryFlow(tester);
    },
  );
}
