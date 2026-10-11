import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/services/location_service.dart';

class DeliveryState extends ChangeNotifier with WidgetsBindingObserver {
  DeliveryState(this.repository, this.uid, {LocationService? locationService})
    : locationService =
          locationService ?? LocationService(requirePrecise: true) {
    WidgetsBinding.instance.addObserver(this);
    _watchProfile();
    _ordersSub = repository
        .ordersFor('courierId', uid)
        .listen(
          (value) {
            orders = value;
            ordersLoading = false;
            ordersError = null;
            if (activeOrder != null) offers = [];
            _notify();
          },
          onError: (Object e) {
            ordersLoading = false;
            ordersError = 'Deliveries could not sync. ${message(e)}';
            _notify();
          },
        );
  }
  final FulfillmentRepository repository;
  final String uid;
  final LocationService locationService;
  StreamSubscription<Map<String, dynamic>?>? _profileSub;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSub;
  Timer? _timer;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> orders = [], offers = [];
  LocationResult? location;
  bool loading = true,
      ordersLoading = true,
      online = false,
      goingOnline = false,
      busy = false,
      _foreground = true,
      _refreshing = false,
      _disposed = false;
  int _generation = 0;
  String? error, profileError, ordersError;
  DateTime? refreshedAt;
  DateTime? locationSyncedAt;
  bool get locating => _refreshing;
  Map<String, dynamic>? get activeOrder => orders
      .where((o) => !['handedOver', 'cancelled'].contains(o['status']))
      .firstOrNull;
  List<Map<String, dynamic>> get completed =>
      orders.where((o) => o['status'] == 'handedOver').toList();
  int get earnings =>
      completed.fold(0, (sum, o) => sum + (o['deliveryFeePaise'] as int));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _watchProfile() {
    _profileSub = repository
        .courier(uid)
        .listen(
          (value) {
            profile = value;
            profileError = null;
            loading = false;
            _notify();
          },
          onError: (Object e) {
            profileError = 'Your profile could not sync. ${message(e)}';
            loading = false;
            _notify();
          },
        );
  }

  Future<void> retryProfileSync() async {
    if (_disposed || loading) return;
    loading = true;
    _notify();
    await _profileSub?.cancel();
    if (!_disposed) _watchProfile();
  }

  Future<void> setOnline(bool value) async {
    if (busy || (!online && _refreshing)) return;
    busy = true;
    goingOnline = value;
    error = null;
    _notify();
    try {
      if (value) {
        // Ask for permission and acquire GPS before publishing availability.
        // Android's permission dialog may temporarily pause the app.
        final generation = _generation;
        _refreshing = true;
        final fix = await _currentLocation();
        _refreshing = false;
        if (_disposed || !_foreground || generation != _generation) return;
        online = true;
        await refresh(initialFix: fix);
        if (online && !_disposed) {
          _timer = Timer.periodic(
            const Duration(seconds: 20),
            (_) => refresh(),
          );
        }
      } else {
        await _offline();
      }
    } catch (e) {
      error = message(e);
    } finally {
      _refreshing = false;
      goingOnline = false;
      busy = false;
      _notify();
    }
  }

  Future<void> _offline() async {
    _generation++;
    online = false;
    locationSyncedAt = null;
    offers = [];
    _timer?.cancel();
    _timer = null;
    _notify();
    await repository.call('presence', {'online': false});
  }

  Future<LocationResult> _currentLocation() async {
    final fix = await locationService.current();
    if (_disposed) return fix;
    location = fix;
    final p = fix.position;
    if (p == null) {
      throw StateError(switch (fix.state) {
        LocationState.denied || LocationState.deniedForever =>
          'Allow precise location in app settings before going online.',
        LocationState.disabled =>
          'Turn on device GPS, then refresh your location.',
        _ => fix.message,
      });
    }
    if (fix.approximate ||
        fix.accuracyMeters == null ||
        !fix.accuracyMeters!.isFinite ||
        fix.accuracyMeters! <= 0 ||
        fix.accuracyMeters! > 150) {
      throw StateError(
        'GPS is too approximate. Enable precise location and try outdoors.',
      );
    }
    if (!p.latitude.isFinite ||
        !p.longitude.isFinite ||
        p.latitude.abs() > 90 ||
        p.longitude.abs() > 180 ||
        fix.capturedAt == null ||
        DateTime.now().difference(fix.capturedAt!).abs() >
            const Duration(seconds: 45)) {
      throw StateError(
        'Your phone returned an old or invalid location. Refresh GPS before going online.',
      );
    }
    return fix;
  }

  /// Offline users can inspect GPS without becoming available for assignments.
  Future<void> refreshLocation() async {
    if (busy || _refreshing || _disposed) return;
    if (online) return refresh();
    _refreshing = true;
    error = null;
    _notify();
    try {
      await _currentLocation();
    } catch (e) {
      if (!_disposed) error = message(e);
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> refresh({LocationResult? initialFix}) async {
    if (_refreshing || !online || _disposed) return;
    _refreshing = true;
    _notify();
    final generation = _generation;
    try {
      final fix = initialFix ?? await _currentLocation();
      if (_disposed || !online || generation != _generation) return;
      await repository.call('presence', {
        'online': true,
        'location': {
          'latitude': fix.position!.latitude,
          'longitude': fix.position!.longitude,
          'accuracy': fix.accuracyMeters,
          'recordedAt': fix.capturedAt!.millisecondsSinceEpoch,
        },
      });
      if (_disposed || !online || generation != _generation) {
        await repository.call('presence', {'online': false});
        return;
      }
      locationSyncedAt = DateTime.now();
      if (activeOrder == null) {
        final result = await repository.call('nearby');
        if (_disposed || !online || generation != _generation) return;
        offers = (result['offers'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
      }
      error = null;
      refreshedAt = DateTime.now();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = message(e);
        try {
          await _offline();
        } catch (_) {}
      }
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> claim(String reference) async {
    if (busy || !online) return;
    busy = true;
    error = null;
    _notify();
    try {
      await refresh();
      if (!online) return;
      await repository.call('claim', {'reference': reference});
      offers = [];
    } catch (e) {
      error = message(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _foreground = true;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      if (online) {
        unawaited(_offline().catchError((Object _) {}));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _profileSub?.cancel();
    _ordersSub?.cancel();
    unawaited(
      repository
          .call('presence', {'online': false})
          .catchError((Object _) => <String, dynamic>{}),
    );
    super.dispose();
  }
}

String message(Object e) {
  if (e is StateError) return e.message;
  if (e is FirebaseException) {
    return switch (e.code) {
      'permission-denied' =>
        'Database access was denied. Delivery profile permissions need to be enabled for this app.',
      'unauthenticated' =>
        'Your session has expired. Sign out and log in again.',
      'unavailable' || 'deadline-exceeded' || 'network-request-failed' =>
        'Check your internet connection and try again.',
      'resource-exhausted' =>
        'The service has reached its usage limit. Please try again later.',
      _ => 'Could not complete this request. Please try again.',
    };
  }
  return 'Could not complete this request. Please try again.';
}
