import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationState {
  idle,
  loading,
  ready,
  denied,
  deniedForever,
  disabled,
  error,
}

class LocationResult {
  const LocationResult(
    this.state,
    this.message, {
    this.position,
    this.accuracyMeters,
    this.capturedAt,
    this.approximate = false,
    this.isMocked = false,
  });
  final LocationState state;
  final String message;
  final LatLng? position;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final bool approximate;
  final bool isMocked;
}

class LocationService {
  LocationService({this.requirePrecise = false});

  /// Delivery discovery needs a new, accurate fix, not the first cached fix.
  final bool requirePrecise;

  /// Startup can refresh an existing grant without opening a permission prompt.
  Future<bool> hasPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(
          LocationState.disabled,
          'Device location is off. Turn it on in settings or choose a delivery pin.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          LocationState.deniedForever,
          'Location permission is blocked. Enable it in app settings or choose a delivery pin.',
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationResult(
          LocationState.denied,
          'Location permission was not granted. You can choose your delivery pin manually.',
        );
      }
      LocationAccuracyStatus? accuracyStatus;
      try {
        accuracyStatus = await Geolocator.getLocationAccuracy();
      } catch (_) {
        // Accuracy permission reporting is not supported on every platform.
      }
      if (requirePrecise && accuracyStatus == LocationAccuracyStatus.reduced) {
        return const LocationResult(
          LocationState.error,
          'Allow precise location in app settings, then refresh your GPS.',
          approximate: true,
        );
      }
      final position = requirePrecise
          ? await Geolocator.getPositionStream(
                  locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.best,
                    distanceFilter: 0,
                  ),
                )
                .where(
                  (p) =>
                      p.latitude.isFinite &&
                      p.longitude.isFinite &&
                      p.latitude.abs() <= 90 &&
                      p.longitude.abs() <= 180 &&
                      p.accuracy.isFinite &&
                      p.accuracy > 0 &&
                      p.accuracy <= 150 &&
                      DateTime.now().difference(p.timestamp).abs() <=
                          const Duration(seconds: 45),
                )
                .timeout(const Duration(seconds: 30))
                .first
          : await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                timeLimit: Duration(seconds: 20),
              ),
            );
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180 ||
          DateTime.now().difference(position.timestamp).abs() >
              const Duration(minutes: 2)) {
        return const LocationResult(
          LocationState.error,
          'The device returned an old or invalid location. Refresh to try again.',
        );
      }
      return LocationResult(
        LocationState.ready,
        'Device location captured',
        position: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy.isFinite && position.accuracy > 0
            ? position.accuracy
            : null,
        capturedAt: position.timestamp,
        approximate: accuracyStatus == LocationAccuracyStatus.reduced,
        isMocked: position.isMocked,
      );
    } on TimeoutException {
      return LocationResult(
        LocationState.error,
        requirePrecise
            ? 'Could not get fresh, precise GPS. Turn on precise location, move outdoors and try again.'
            : 'Location timed out. Try again outdoors or choose a delivery pin.',
      );
    } catch (_) {
      return const LocationResult(
        LocationState.error,
        'Could not read your location. Refresh or choose a delivery pin.',
      );
    }
  }

  Future<bool> settings({required bool appSettings}) async {
    try {
      return appSettings
          ? await Geolocator.openAppSettings()
          : await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
