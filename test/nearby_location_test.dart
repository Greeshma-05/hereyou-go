import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/mock_journeys.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/models/nearby_area.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/providers/location_provider.dart';
import 'package:route_rescue/screens/explore/explore_screen.dart';
import 'package:route_rescue/services/location_service.dart';
import 'package:route_rescue/widgets/vendor_card.dart';
import 'catalog_search_test.dart' show shop, supply;
import 'support/demo_flow.dart';

class FakeGps extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool enabled = true;
  bool reduced = false;
  DateTime timestamp = DateTime.now();
  LocationSettings? requestedSettings;
  Object? failure;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      reduced ? LocationAccuracyStatus.reduced : LocationAccuracyStatus.precise;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requestedSettings = locationSettings;
    if (failure != null) throw failure!;
    return Position(
      latitude: 9.85,
      longitude: 76.29,
      timestamp: timestamp,
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: true,
    );
  }
}

class PendingLocation extends LocationService {
  final completion = Completer<LocationResult>();
  @override
  Future<LocationResult> current() => completion.future;
}

void main() {
  test(
    'bus and train include the closest shops through their inclusive maximum radius',
    () {
      final bus = NearbyArea(
        mode: JourneyMode.bus,
        devicePosition: kochiCenter,
      );
      final train = NearbyArea(
        mode: JourneyMode.train,
        devicePosition: kochiCenter,
      );
      final distance = const Distance(roundResult: false);
      LatLng north(double meters) => distance.offset(kochiCenter, meters, 0);
      expect(bus.contains(north(0)), isTrue);
      expect(bus.contains(north(4999)), isTrue);
      expect(bus.contains(north(5000)), isTrue);
      expect(bus.contains(north(5001)), isTrue);
      expect(bus.contains(north(6999)), isTrue);
      expect(bus.contains(north(7000)), isTrue);
      expect(bus.contains(north(7001)), isFalse);
      expect(train.contains(north(0)), isTrue);
      expect(train.contains(north(7001)), isTrue);
      expect(train.contains(north(9999)), isTrue);
      expect(train.contains(north(10000)), isTrue);
      expect(train.contains(north(10001)), isTrue);
      expect(train.contains(north(19999)), isTrue);
      expect(train.contains(north(20000)), isTrue);
      expect(train.contains(north(20001)), isFalse);
    },
  );

  test('GPS wins over delivery pin; fallback is explicitly labelled', () {
    final area = NearbyArea(
      mode: JourneyMode.bus,
      devicePosition: const LatLng(9.85, 76.29),
      pickup: busStops.first,
    );
    expect(area.center, const LatLng(9.85, 76.29));
    expect(area.source, 'device location');
    final manual = NearbyArea(
      mode: JourneyMode.train,
      pickup: trainStops.first,
    );
    expect(manual.center, trainStops.first.position);
    expect(manual.source, 'delivery pin');
    expect(NearbyArea(mode: JourneyMode.bus).isPreview, isTrue);
  });

  test(
    'shop and product filters agree and still rank matching stock first',
    () {
      final vendors = [shop('empty'), shop('stock')];
      final products = [supply('a', 'empty', stock: 0), supply('b', 'stock')];
      final near = NearbyArea(
        mode: JourneyMode.bus,
        devicePosition: const LatLng(9.92, 76.29),
      );
      final far = NearbyArea(
        mode: JourneyMode.bus,
        devicePosition: const LatLng(9.80, 76.29),
      );
      expect(
        Catalog.searchVendorResults(
          'saline',
          null,
          area: near,
          vendors: vendors,
          products: products,
        ).map((r) => r.vendor.id),
        ['stock', 'empty'],
      );
      expect(
        Catalog.searchVendorResults(
          'saline',
          null,
          area: far,
          vendors: vendors,
          products: products,
        ),
        isEmpty,
      );
      expect(
        Catalog.searchProducts(
          'saline',
          null,
          area: far,
          vendors: vendors,
          products: products,
        ),
        isEmpty,
      );
    },
  );

  group('native location service contract', () {
    late GeolocatorPlatform original;
    late FakeGps gps;
    setUp(() {
      original = GeolocatorPlatform.instance;
      gps = FakeGps();
      GeolocatorPlatform.instance = gps;
    });
    tearDown(() => GeolocatorPlatform.instance = original);
    test(
      'startup restores an existing GPS grant and stays idle without permission',
      () async {
        gps.permission = LocationPermission.denied;
        final location = LocationProvider();
        await location.restoreIfPermitted();
        expect(location.result.state, LocationState.idle);
        expect(gps.requestedSettings, isNull);
        gps.permission = LocationPermission.whileInUse;
        await location.restoreIfPermitted();
        expect(location.position, const LatLng(9.85, 76.29));
        location.dispose();
      },
    );
    test(
      'requests best accuracy and retains timestamp, precision and test metadata',
      () async {
        gps.reduced = true;
        final result = await LocationService().current();
        expect(gps.requestedSettings!.accuracy, LocationAccuracy.best);
        expect(gps.requestedSettings!.timeLimit, const Duration(seconds: 20));
        expect(result.position, const LatLng(9.85, 76.29));
        expect(result.accuracyMeters, 12);
        expect(result.capturedAt, gps.timestamp);
        expect(result.approximate, isTrue);
        expect(result.isMocked, isTrue);
      },
    );
    test('old fixes and timeouts never become a current position', () async {
      gps.timestamp = DateTime.now().subtract(const Duration(minutes: 10));
      expect((await LocationService().current()).position, isNull);
      gps.failure = TimeoutException('timeout');
      final result = await LocationService().current();
      expect(result.state, LocationState.error);
      expect(result.position, isNull);
    });
    test(
      'blocked permission and disabled GPS do not request coordinates',
      () async {
        gps.permission = LocationPermission.deniedForever;
        expect(
          (await LocationService().current()).state,
          LocationState.deniedForever,
        );
        gps.enabled = false;
        expect(
          (await LocationService().current()).state,
          LocationState.disabled,
        );
        expect(gps.requestedSettings, isNull);
      },
    );
    testWidgets(
      'Explore refresh centers GPS, filters maps and lists and changes range',
      (tester) async {
        final location = LocationProvider();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(create: (_) => JourneyProvider()),
              ChangeNotifierProvider.value(value: location),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const ExploreScreen(initialMap: false),
            ),
          ),
        );
        await tapVisible(tester, find.byTooltip('Find my location'));
        expect(find.text('9.850000, 76.290000'), findsOneWidget);
        expect(find.textContaining('Reported accuracy: ±12 m'), findsOneWidget);
        expect(find.byType(VendorCard), findsNothing);
        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(map.mapController!.camera.center, const LatLng(9.85, 76.29));
        final markers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers;
        expect(
          markers.where(
            (m) => m.key?.toString().contains('map-vendor-') == true,
          ),
          isEmpty,
        );
        await tapVisible(tester, find.text('Train · within 20 km'));
        expect(find.byType(VendorCard), findsNWidgets(5));
        expect(
          tester
              .widget<MarkerLayer>(find.byType(MarkerLayer))
              .markers
              .where((m) => m.key?.toString().contains('map-vendor-') == true),
          hasLength(5),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        location.dispose();
      },
    );
    testWidgets(
      'location controls fit a narrow screen with large reading text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        gps.reduced = true;
        final location = LocationProvider();
        await location.locate();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(create: (_) => JourneyProvider()),
              ChangeNotifierProvider.value(value: location),
            ],
            child: MaterialApp(
              theme: AppTheme.build(readingFont: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.95)),
                child: child!,
              ),
              home: const ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Train · within 20 km'));
        expect(find.textContaining('Location is approximate'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        location.dispose();
      },
    );
  });

  test(
    'late GPS responses cannot repopulate cleared or disposed account state',
    () async {
      for (final dispose in [false, true]) {
        final service = PendingLocation();
        final provider = LocationProvider(service: service);
        final pending = provider.locate();
        if (dispose) {
          provider.dispose();
        } else {
          provider.clear();
        }
        service.completion.complete(
          const LocationResult(
            LocationState.ready,
            'Found',
            position: kochiCenter,
          ),
        );
        await pending;
        expect(provider.position, isNull);
        if (!dispose) provider.dispose();
      }
    },
  );
}
