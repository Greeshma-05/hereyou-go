import 'package:latlong2/latlong.dart';

class DeliveryRoute {
  DeliveryRoute({
    required List<LatLng> points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fetchedAt,
  }) : points = List.unmodifiable(points);

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final DateTime fetchedAt;
  int get drivingMinutes => (durationSeconds / 60).ceil().clamp(1, 1000000);

  static DeliveryRoute fromOsrm(Map<String, dynamic> data) {
    if (data['code'] != 'Ok') throw const FormatException('No road route');
    final routes = data['routes'] as List;
    if (routes.isEmpty) throw const FormatException('No road route');
    final route = routes.first as Map;
    final geometry = route['geometry'] as Map;
    if (geometry['type'] != 'LineString') {
      throw const FormatException('Invalid geometry');
    }
    final coordinates = geometry['coordinates'] as List;
    if (coordinates.length < 2 || coordinates.length > 100000) {
      throw const FormatException('Invalid route length');
    }
    final points = coordinates.map((value) {
      final pair = value as List;
      final longitude = (pair[0] as num).toDouble();
      final latitude = (pair[1] as num).toDouble();
      if (!validCoordinates(latitude, longitude)) {
        throw const FormatException('Invalid coordinates');
      }
      return LatLng(latitude, longitude);
    }).toList();
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();
    if (!distance.isFinite ||
        distance < 0 ||
        !duration.isFinite ||
        duration < 0) {
      throw const FormatException('Invalid route estimates');
    }
    return DeliveryRoute(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
      fetchedAt: DateTime.now(),
    );
  }
}

bool validCoordinates(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;
