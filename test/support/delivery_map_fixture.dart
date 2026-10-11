import 'package:latlong2/latlong.dart';
import 'package:route_rescue/models/delivery_route.dart';
import 'package:route_rescue/services/delivery_routing_service.dart';

// Deterministic routing data for tests only. Never used by the shipped app.
class FixtureRoutingService extends DeliveryRoutingService {
  int calls = 0;
  bool fail = false;
  @override
  Future<DeliveryRoute> route(LatLng shop, LatLng delivery) async {
    calls++;
    if (fail) {
      throw const RoutingException(
        'Test route unavailable. Retry when connected.',
      );
    }
    return DeliveryRoute(
      points: [shop, LatLng(shop.latitude, delivery.longitude), delivery],
      distanceMeters: 1600,
      durationSeconds: 330,
      fetchedAt: DateTime.now(),
    );
  }
}
