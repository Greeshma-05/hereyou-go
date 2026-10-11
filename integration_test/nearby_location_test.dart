import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/providers/location_provider.dart';
import 'package:route_rescue/services/location_service.dart';
import 'package:route_rescue/widgets/vendor_card.dart';
import '../test/support/demo_flow.dart';

// Before running, grant location permission on the test emulator and set its
// position: adb emu geo fix 76.29 9.85. This verifies the actual native plugin.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android GPS fixes drive bus/train radius and Explore map', (
    tester,
  ) async {
    await tester.pumpWidget(const RouteRescueApp());
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Get Started'));
    await tapVisible(tester, find.text('Continue as guest'));
    await tapVisible(tester, find.byTooltip('Explore'));
    final provider = tester
        .element(find.byType(FlutterMap))
        .read<LocationProvider>();
    await tapVisible(tester, find.byTooltip('Find my location'));
    for (
      var i = 0;
      i < 25 && provider.result.state == LocationState.loading;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pumpAndSettle();
    }
    expect(
      provider.result.state,
      LocationState.ready,
      reason: provider.result.message,
    );
    expect(provider.position!.latitude, closeTo(9.85, .001));
    expect(provider.position!.longitude, closeTo(76.29, .001));
    expect(provider.fix!.accuracyMeters, isNotNull);
    expect(provider.fix!.capturedAt, isNotNull);
    expect(
      find.byKey(const ValueKey('device-location-marker')),
      findsOneWidget,
    );
    expect(find.byType(VendorCard), findsNothing);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center.latitude, closeTo(9.85, .001));
    await tapVisible(tester, find.text('Train · within 20 km'));
    expect(find.byType(VendorCard), findsNWidgets(5));
    final markers = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers;
    expect(
      markers.where((m) => m.key?.toString().contains('map-vendor-') == true),
      hasLength(5),
    );
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('here-you-go-nearby-gps');
    expect(tester.takeException(), isNull);
  });
}
