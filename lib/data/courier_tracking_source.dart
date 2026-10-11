import 'package:latlong2/latlong.dart';
import '../models/delivery_route.dart';

/// Future backend adapters expose only the courier assigned to this order.
/// Customer GPS must never be published as courier GPS.
abstract class CourierTrackingSource {
  bool get connected;
  Stream<CourierFix?> watch(String orderReference);
}

class UnavailableCourierTracking implements CourierTrackingSource {
  const UnavailableCourierTracking();
  @override
  bool get connected => false;
  @override
  Stream<CourierFix?> watch(String orderReference) => Stream.value(null);
}

class CourierFix {
  const CourierFix({
    required this.position,
    required this.recordedAt,
    this.accuracyMeters,
    this.name,
  });
  final LatLng position;
  final DateTime recordedAt;
  final double? accuracyMeters;
  final String? name;
  bool get isValid =>
      validCoordinates(position.latitude, position.longitude) &&
      (accuracyMeters == null ||
          accuracyMeters!.isFinite && accuracyMeters! > 0);
  bool isFresh(DateTime now) {
    final age = now.difference(recordedAt);
    return isValid &&
        age >= const Duration(seconds: -30) &&
        age <= const Duration(seconds: 90);
  }
}
