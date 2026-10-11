import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/services/location_service.dart';
import 'package:routerescue_partner/live/delivery_state.dart';

class Api extends Fake implements FulfillmentRepository {
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? presenceGate;
  StreamController<Map<String, dynamic>?>? profiles;
  int profileSubscriptions = 0;
  @override
  Stream<Map<String, dynamic>?> courier(String uid) {
    profileSubscriptions++;
    return profiles?.stream ?? Stream.value({'name': 'Asha', 'online': false});
  }

  @override
  Stream<List<Map<String, dynamic>>> ordersFor(String field, String uid) =>
      Stream.value([]);
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add({'action': action, ...data});
    if (action == 'presence' &&
        data['online'] == true &&
        presenceGate != null) {
      return presenceGate!.future;
    }
    return action == 'nearby'
        ? {
            'offers': [
              {'reference': 'order-1'},
            ],
            'radiusKm': 5,
          }
        : {};
  }
}

class Gps extends LocationService {
  Completer<LocationResult>? gate;
  LocationResult? result;
  bool denied = false;
  @override
  Future<LocationResult> current() async =>
      gate?.future ??
      result ??
      (denied
          ? const LocationResult(LocationState.denied, 'denied')
          : LocationResult(
              LocationState.ready,
              'ready',
              position: const LatLng(9.97, 76.29),
              accuracyMeters: 10,
              capturedAt: DateTime.now(),
            ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'profile permission failures are distinct from connection failures',
    () async {
      final profiles = StreamController<Map<String, dynamic>?>.broadcast();
      final api = Api()..profiles = profiles;
      final state = DeliveryState(api, 'partner', locationService: Gps());
      profiles.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.loading, isFalse);
      expect(state.profileError, contains('Database access was denied'));
      expect(state.profileError, isNot(contains('Check your connection')));
      expect(state.error, isNull);
      await state.retryProfileSync();
      expect(api.profileSubscriptions, 2);
      profiles.add({'name': 'Saved partner'});
      await Future<void>.delayed(Duration.zero);
      expect(state.profile?['name'], 'Saved partner');
      expect(state.profileError, isNull);
      expect(state.loading, isFalse);
      state.dispose();
      await profiles.close();
    },
  );
  test(
    'a recovered profile sync clears its error without hiding GPS errors',
    () async {
      final profiles = StreamController<Map<String, dynamic>?>.broadcast();
      final state = DeliveryState(
        Api()..profiles = profiles,
        'partner',
        locationService: Gps()..denied = true,
      );
      profiles.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.profileError, contains('internet connection'));
      await state.setOnline(true);
      profiles.add({'name': 'Saved partner'});
      await Future<void>.delayed(Duration.zero);
      expect(state.profileError, isNull);
      expect(state.error, contains('Allow precise location'));
      state.dispose();
      await profiles.close();
    },
  );
  test(
    'online refresh sends fresh GPS before requesting nearby offers',
    () async {
      final api = Api();
      final live = DeliveryState(api, 'partner', locationService: Gps());
      await live.setOnline(true);
      expect(api.calls.map((c) => c['action']), ['presence', 'nearby']);
      expect(live.offers.single['reference'], 'order-1');
      await live.setOnline(false);
      expect(live.offers, isEmpty);
      expect(live.online, isFalse);
      live.dispose();
    },
  );
  test(
    'offline GPS check has no default location and publishes no availability',
    () async {
      final api = Api();
      final state = DeliveryState(api, 'partner', locationService: Gps());
      expect(state.location, isNull);
      await state.refreshLocation();
      expect(state.location!.position, const LatLng(9.97, 76.29));
      expect(state.online, isFalse);
      expect(state.locationSyncedAt, isNull);
      expect(api.calls, isEmpty);
      state.dispose();
    },
  );
  test(
    'refresh uses the new device position and confirms database sync',
    () async {
      final api = Api(), gps = Gps();
      final state = DeliveryState(api, 'partner', locationService: gps);
      await state.setOnline(true);
      gps.result = LocationResult(
        LocationState.ready,
        'ready',
        position: const LatLng(11.25, 75.78),
        accuracyMeters: 8,
        capturedAt: DateTime.now(),
      );
      await state.refreshLocation();
      final presence = api.calls.lastWhere((c) => c['action'] == 'presence');
      expect(presence['location']['latitude'], 11.25);
      expect(presence['location']['longitude'], 75.78);
      expect(state.locationSyncedAt, isNotNull);
      await state.setOnline(false);
      expect(state.locationSyncedAt, isNull);
      state.dispose();
    },
  );
  for (final invalid in [
    'old',
    'approximate',
    'missing timestamp',
    'invalid accuracy',
  ]) {
    test('$invalid GPS cannot publish an online partner', () async {
      final api = Api(), gps = Gps();
      gps.result = LocationResult(
        LocationState.ready,
        'ready',
        position: const LatLng(9.97, 76.29),
        accuracyMeters: invalid == 'invalid accuracy' ? double.nan : 10,
        approximate: invalid == 'approximate',
        capturedAt: invalid == 'missing timestamp'
            ? null
            : DateTime.now().subtract(
                Duration(seconds: invalid == 'old' ? 70 : 0),
              ),
      );
      final state = DeliveryState(api, 'partner', locationService: gps);
      await state.setOnline(true);
      expect(state.online, isFalse);
      expect(state.locationSyncedAt, isNull);
      expect(state.error, isNotNull);
      expect(api.calls.any((c) => c['online'] == true), isFalse);
      state.dispose();
    });
  }
  test(
    'denied GPS never publishes an online presence or exposes offers',
    () async {
      final api = Api(), gps = Gps()..denied = true;
      final state = DeliveryState(api, 'partner', locationService: gps);
      await state.setOnline(true);
      expect(state.online, isFalse);
      expect(state.error, contains('Allow precise location'));
      expect(api.calls.any((c) => c['online'] == true), isFalse);
      expect(state.offers, isEmpty);
      state.dispose();
    },
  );
  test(
    'backgrounding during GPS acquisition cannot revive online sharing',
    () async {
      final api = Api(), gps = Gps()..gate = Completer<LocationResult>();
      final state = DeliveryState(api, 'partner', locationService: gps);
      final pending = state.setOnline(true);
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      gps.gate!.complete(
        LocationResult(
          LocationState.ready,
          'ready',
          position: const LatLng(9.97, 76.29),
          accuracyMeters: 10,
          capturedAt: DateTime.now(),
        ),
      );
      await pending;
      expect(state.online, isFalse);
      expect(api.calls.any((c) => c['online'] == true), isFalse);
      expect(state.offers, isEmpty);
      state.dispose();
    },
  );
  test(
    'returning from the first permission prompt completes going online',
    () async {
      final api = Api(), gps = Gps()..gate = Completer<LocationResult>();
      final state = DeliveryState(api, 'partner', locationService: gps);
      final pending = state.setOnline(true);
      expect(state.online, isFalse);
      expect(state.goingOnline, isTrue);
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      gps.gate!.complete(
        LocationResult(
          LocationState.ready,
          'ready',
          position: const LatLng(9.97, 76.29),
          accuracyMeters: 10,
          capturedAt: DateTime.now(),
        ),
      );
      await pending;
      expect(state.online, isTrue);
      expect(state.goingOnline, isFalse);
      expect(state.locationSyncedAt, isNotNull);
      expect(api.calls.where((c) => c['online'] == true), hasLength(1));
      state.dispose();
    },
  );
  test(
    'late online server acknowledgement is followed by an offline correction',
    () async {
      final api = Api()..presenceGate = Completer<Map<String, dynamic>>();
      final state = DeliveryState(api, 'partner', locationService: Gps());
      final pending = state.setOnline(true);
      await Future<void>.delayed(Duration.zero);
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      api.presenceGate!.complete({});
      await pending;
      expect(api.calls.last['online'], isFalse);
      expect(api.calls.any((c) => c['action'] == 'nearby'), isFalse);
      expect(state.online, isFalse);
      state.dispose();
    },
  );
}
