import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:routerescue_partner/live/delivery_app.dart';
import 'package:routerescue_partner/live/delivery_state.dart';
import 'package:route_rescue/services/location_service.dart';
import 'live_delivery_state_test.dart' show Api, Gps;

void main() {
  testWidgets(
    'GPS controls work while offline and show the actual phone reading',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = Api(), gps = Gps()..gate = Completer<LocationResult>();
      final state = DeliveryState(api, 'partner', locationService: gps);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: state,
                builder: (_, _) => DeliveryLocationCard(state: state),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No default city'), findsOneWidget);
      final refresh = find.widgetWithText(
        OutlinedButton,
        'Use my current location',
      );
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pump();
      expect(find.text('Getting fresh GPS…'), findsOneWidget);
      gps.gate!.complete(
        LocationResult(
          LocationState.ready,
          'ready',
          position: const LatLng(11.25, 75.78),
          accuracyMeters: 8,
          capturedAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Last reading: 11.25000, 75.78000'), findsOneWidget);
      expect(find.text('GPS accuracy: ±8 m'), findsOneWidget);
      expect(find.textContaining('Offline ·'), findsOneWidget);
      expect(api.calls, isEmpty);
      expect(find.text('Location permission'), findsOneWidget);
      expect(find.text('Device GPS settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('map follows new GPS and can recenter after panning', (
    tester,
  ) async {
    Future<void> render(LatLng point) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyMap(position: point, offers: const []),
        ),
      ),
    );
    const initial = LatLng(11.25, 75.78), moved = LatLng(11.2501, 75.7801);
    await render(initial);
    await tester.pump();
    var map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center, initial);
    await render(moved);
    await tester.pump();
    map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center, moved);
    map.mapController!.move(const LatLng(12, 76), 12);
    await tester.pump();
    await tester.tap(find.byTooltip('Center map on my GPS location'));
    await tester.pump();
    expect(map.mapController!.camera.center, moved);
    expect(map.mapController!.camera.zoom, 15);
    await tester.pumpWidget(const SizedBox());
  });
}
