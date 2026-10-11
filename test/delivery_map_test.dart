import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/courier_tracking_source.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/models/delivery_route.dart';
import 'package:route_rescue/providers/delivery_map_provider.dart';
import 'package:route_rescue/providers/location_provider.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'package:route_rescue/screens/orders/delivery_map_screen.dart';
import 'package:route_rescue/screens/orders/order_detail_screen.dart';
import 'package:route_rescue/services/delivery_routing_service.dart';
import 'state_test.dart' show sampleJourney;
import 'support/delivery_map_fixture.dart';
import 'support/demo_flow.dart' show tapVisible;

Map<String, dynamic> routeJson() => {
  'code': 'Ok',
  'routes': [
    {
      'distance': 1600,
      'duration': 330,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [76.289, 9.9772],
          [76.291, 9.9785],
        ],
      },
    },
  ],
};

class TestTracking implements CourierTrackingSource {
  final controller = StreamController<CourierFix?>();
  @override
  bool get connected => true;
  @override
  Stream<CourierFix?> watch(String reference) => controller.stream;
}

class PendingRouting extends DeliveryRoutingService {
  final completion = Completer<DeliveryRoute>();
  @override
  Future<DeliveryRoute> route(LatLng shop, LatLng delivery) =>
      completion.future;
}

Future<void> flushStream() => Future<void>.delayed(Duration.zero);

void main() {
  test('road route decodes longitude first and rejects unusable geometry', () {
    final route = DeliveryRoute.fromOsrm(routeJson());
    expect(route.points.first, const LatLng(9.9772, 76.289));
    expect(route.distanceMeters, 1600);
    expect(route.drivingMinutes, 6);
    expect(
      () => DeliveryRoute.fromOsrm({'code': 'NoRoute'}),
      throwsFormatException,
    );
    final invalid = routeJson();
    (invalid['routes'] as List).first['geometry']['coordinates'][0] = [
      190.0,
      9.0,
    ];
    expect(() => DeliveryRoute.fromOsrm(invalid), throwsFormatException);
    final negative = routeJson();
    (negative['routes'] as List).first['duration'] = -1;
    expect(() => DeliveryRoute.fromOsrm(negative), throwsFormatException);
  });

  test(
    'routing request sends only coordinates and required route options',
    () async {
      final service = DeliveryRoutingService(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(
            request.url.path,
            contains('/route/v1/driving/76.289000,9.977200;76.291000,9.978500'),
          );
          expect(request.url.queryParameters['geometries'], 'geojson');
          expect(request.url.queryParameters['radiuses'], '250;250');
          expect(request.body, isEmpty);
          expect(request.headers['User-Agent'], contains('HereYouGo'));
          return http.Response(jsonEncode(routeJson()), 200);
        }),
      );
      final result = await service.route(
        const LatLng(9.9772, 76.289),
        const LatLng(9.9785, 76.291),
      );
      expect(result.drivingMinutes, 6);
      service.dispose();
    },
  );

  test('no nearby road is explained without manufacturing a route', () async {
    final service = DeliveryRoutingService(
      client: MockClient(
        (_) async => http.Response('{"code":"NoSegment"}', 400),
      ),
    );
    final state = DeliveryMapProvider(
      reference: 'test',
      shop: const LatLng(9, 76),
      delivery: const LatLng(10, 76),
      routing: service,
    );
    await state.loadRoute();
    expect(state.roadRoute, isNull);
    expect(state.error, contains('No driving route'));
    expect(state.loading, isFalse);
    state.dispose();
  });

  test(
    'courier stream rejects invalid or older fixes and reports closed connection',
    () async {
      final tracking = TestTracking();
      final state = DeliveryMapProvider(
        reference: 'test',
        shop: null,
        delivery: const LatLng(9, 76),
        tracking: tracking,
        routing: FixtureRoutingService(),
      );
      final now = DateTime.now();
      expect(state.courier, isNull);
      final current = CourierFix(
        position: const LatLng(9, 76),
        recordedAt: now,
        accuracyMeters: 10,
      );
      tracking.controller.add(current);
      await flushStream();
      expect(state.courierLive, isTrue);
      tracking.controller.add(
        CourierFix(
          position: const LatLng(8, 76),
          recordedAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      tracking.controller.add(
        CourierFix(
          position: const LatLng(8, 76),
          recordedAt: now.add(const Duration(minutes: 2)),
        ),
      );
      tracking.controller.add(
        CourierFix(
          position: const LatLng(8, 76),
          recordedAt: now,
          accuracyMeters: -1,
        ),
      );
      await flushStream();
      expect(state.courier, same(current));
      tracking.controller.addError(StateError('offline'));
      await flushStream();
      expect(state.courierLive, isFalse);
      expect(state.courier, same(current));
      tracking.controller.add(current);
      await flushStream();
      expect(state.courierLive, isTrue);
      await tracking.controller.close();
      expect(state.courierLive, isFalse);
      expect(
        CourierFix(
          position: current.position,
          recordedAt: now.subtract(const Duration(minutes: 2)),
        ).isFresh(now),
        isFalse,
      );
      state.dispose();
    },
  );

  test('missing shop and disposed requests remain safe', () async {
    final missing = DeliveryMapProvider(
      reference: 'test',
      shop: null,
      delivery: const LatLng(9, 76),
      routing: FixtureRoutingService(),
    );
    await missing.loadRoute();
    expect(missing.error, contains('shop location is unavailable'));
    expect(missing.courier, isNull);
    missing.dispose();
    final service = PendingRouting();
    final pending = DeliveryMapProvider(
      reference: 'test',
      shop: const LatLng(9, 76),
      delivery: const LatLng(10, 76),
      routing: service,
    );
    final load = pending.loadRoute();
    pending.dispose();
    service.completion.complete(DeliveryRoute.fromOsrm(routeJson()));
    await load;
    expect(pending.roadRoute, isNull);
  });

  Future<({OrderProvider orders, String reference})> seedOrder() async {
    final orders = OrderProvider();
    final order = await orders.place([
      CartItem(Catalog.product('meal'), 1),
    ], sampleJourney());
    addTearDown(orders.dispose);
    return (orders: orders, reference: order.reference);
  }

  Widget host(
    OrderProvider orders,
    Widget screen, {
    double scale = 1,
    bool reading = false,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: orders),
      ChangeNotifierProvider(create: (_) => LocationProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.build(readingFont: reading),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: screen,
    ),
  );

  testWidgets(
    'order details opens pins without sharing coordinates or inventing courier position',
    (tester) async {
      final order = await seedOrder();
      await tester.pumpWidget(
        host(order.orders, OrderDetailScreen(reference: order.reference)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('View delivery map'));
      expect(find.byKey(const ValueKey('order-delivery-map')), findsOneWidget);
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(
        markers.map((m) => m.key),
        containsAll([
          const ValueKey('delivery-shop-pin'),
          const ValueKey('delivery-destination-pin'),
        ]),
      );
      expect(
        markers.any((m) => m.key == const ValueKey('delivery-courier-pin')),
        isFalse,
      );
      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.text('Courier tracking not connected'), findsOneWidget);
      order.orders.advance(order.reference);
      await tester.pumpAndSettle();
      expect(find.text('Vendor confirmation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'route is opt-in, retry recovers and text size does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('OpenDyslexic')
        ..addFont(rootBundle.load('assets/fonts/OpenDyslexic-Regular.otf'))
        ..addFont(rootBundle.load('assets/fonts/OpenDyslexic-Bold.otf'));
      await font.load();
      final order = await seedOrder();
      final routing = FixtureRoutingService()..fail = true;
      await tester.pumpWidget(
        host(
          order.orders,
          DeliveryMapScreen(
            reference: order.reference,
            routingService: routing,
          ),
          scale: 1.95,
          reading: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(routing.calls, 0);
      await tapVisible(tester, find.text('Show road route'));
      await tapVisible(tester, find.text('Keep pins only'));
      expect(routing.calls, 0);
      await tapVisible(tester, find.text('Show road route'));
      await tapVisible(tester, find.text('Calculate route'));
      expect(routing.calls, 1);
      expect(find.byType(PolylineLayer), findsNothing);
      routing.fail = false;
      await tapVisible(tester, find.text('Retry road route'));
      expect(routing.calls, 2);
      expect(find.text('1.6 km · about 6 min'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      await tapVisible(tester, find.text('Order & delivery details'));
      expect(find.textContaining('Delivery pin: 9.978500'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
