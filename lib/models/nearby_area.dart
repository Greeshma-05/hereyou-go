import 'package:latlong2/latlong.dart';
import '../data/mock_journeys.dart';
import 'journey_model.dart';

/// The same unrounded, straight-line distance policy is used by maps and lists.
class NearbyArea {
  NearbyArea({required this.mode, LatLng? devicePosition, PickupStop? pickup})
    : center = devicePosition ?? pickup?.position ?? kochiCenter,
      source = devicePosition != null
          ? 'device location'
          : pickup != null
          ? 'delivery pin'
          : 'Kochi preview',
      isPreview = devicePosition == null && pickup == null;

  final JourneyMode mode;
  final LatLng center;
  final String source;
  final bool isPreview;
  double get minimumKm => 0;
  double get radiusKm => mode == JourneyMode.bus ? 7 : 20;
  String get distanceLabel => 'within ${radiusKm.toInt()} km';
  String get rangeLabel =>
      '${mode == JourneyMode.bus ? 'Bus' : 'Train'} · $distanceLabel';
  double distanceKm(LatLng point) =>
      const Distance(roundResult: false)(center, point) / 1000;
  bool contains(LatLng point) {
    final distance = distanceKm(point);
    // Allow for sub-millimetre floating-point error at the inclusive edges.
    const toleranceKm = 1e-7;
    return distance >= minimumKm - toleranceKm &&
        distance <= radiusKm + toleranceKm;
  }
}
