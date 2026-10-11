import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  LocationProvider({LocationService? service})
    : _service = service ?? LocationService();
  final LocationService _service;
  LocationResult _result = const LocationResult(
    LocationState.idle,
    'Tap the location icon to find shops near you.',
  );
  LocationResult get result => _result;
  LocationResult? _fix;
  LocationResult? get fix => _fix;
  LatLng? get position => _fix?.position;
  int _generation = 0;
  bool _disposed = false;
  Future<void> restoreIfPermitted() async {
    final generation = _generation;
    final permitted = await _service.hasPermission();
    if (!_disposed && generation == _generation && permitted) await locate();
  }

  Future<void> locate() async {
    if (_result.state == LocationState.loading) return;
    final generation = ++_generation;
    _result = const LocationResult(
      LocationState.loading,
      'Finding your location…',
    );
    notifyListeners();
    final next = await _service.current();
    if (_disposed || generation != _generation) return;
    _result = next;
    if (next.state == LocationState.ready) _fix = next;
    if ([
      LocationState.denied,
      LocationState.deniedForever,
      LocationState.disabled,
    ].contains(next.state)) {
      _fix = null;
    }
    notifyListeners();
  }

  Future<bool> openSettings({bool preciseLocation = false}) =>
      _service.settings(
        appSettings:
            preciseLocation || _result.state == LocationState.deniedForever,
      );
  void clear() {
    _generation++;
    _fix = null;
    _result = const LocationResult(
      LocationState.idle,
      'Tap the location icon to find shops near you.',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
