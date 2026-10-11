import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:route_rescue/services/location_service.dart';

class StreamingGps extends GeolocatorPlatform {
  final fixes = StreamController<Position>.broadcast();
  bool precise = true;
  int subscriptions = 0;
  LocationSettings? requestedSettings;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      precise ? LocationAccuracyStatus.precise : LocationAccuracyStatus.reduced;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    subscriptions++;
    requestedSettings = locationSettings;
    return fixes.stream;
  }
}

Position fix({int age = 0, double accuracy = 8}) => Position(
  latitude: 11.25,
  longitude: 75.78,
  timestamp: DateTime.now().subtract(Duration(seconds: age)),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late GeolocatorPlatform original;
  late StreamingGps gps;
  setUp(() {
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = gps = StreamingGps();
  });
  tearDown(() async {
    GeolocatorPlatform.instance = original;
    await gps.fixes.close();
  });
  test(
    'delivery GPS skips cached and inaccurate fixes then cancels its stream',
    () async {
      var completed = false;
      final pending = LocationService(requirePrecise: true).current().then((r) {
        completed = true;
        return r;
      });
      await Future<void>.delayed(Duration.zero);
      gps.fixes.add(fix(age: 100));
      gps.fixes.add(fix(accuracy: 1500));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      gps.fixes.add(fix());
      final result = await pending;
      expect(result.position!.latitude, 11.25);
      expect(result.position!.longitude, 75.78);
      expect(result.accuracyMeters, 8);
      expect(gps.requestedSettings!.accuracy, LocationAccuracy.best);
      await Future<void>.delayed(Duration.zero);
      expect(gps.fixes.hasListener, isFalse);
    },
  );
  test(
    'approximate permission is actionable and never starts a GPS stream',
    () async {
      gps.precise = false;
      final result = await LocationService(requirePrecise: true).current();
      expect(result.position, isNull);
      expect(result.message, contains('precise location in app settings'));
      expect(gps.subscriptions, 0);
    },
  );
  testWidgets(
    'a GPS timeout cancels the stream and never returns a fallback pin',
    (tester) async {
      final pending = LocationService(requirePrecise: true).current();
      await tester.pump();
      expect(gps.subscriptions, 1);
      expect(gps.fixes.hasListener, isTrue);
      await tester.pump(const Duration(seconds: 31));
      final result = await pending;
      expect(result.position, isNull);
      expect(result.message, contains('fresh, precise GPS'));
      expect(gps.fixes.hasListener, isFalse);
    },
  );
}
