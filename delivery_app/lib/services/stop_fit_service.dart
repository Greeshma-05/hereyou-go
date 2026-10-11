import '../models/delivery_request.dart';
import '../models/stop_fit_result.dart';

class StopFitService {
  const StopFitService();
  // Demo only: 20 km/h for the pickup + detour, plus waiting and 5 min handling.
  StopFitResult evaluate(DeliveryRequest order) {
    final minutes =
        ((order.pickupKm + order.detourKm) * 3).ceil() + order.waitMinutes + 5;
    final margin = order.availableMinutes - minutes;
    if (!order.matchesRoute || order.detourKm > 6) {
      return StopFitResult(
        StopFitClassification.mismatch,
        'This order requires a significant detour from your journey.',
        minutes,
        margin,
      );
    }
    if (margin < 8) {
      return StopFitResult(
        StopFitClassification.tight,
        'Limited time remaining before handover. Review the demo timing carefully.',
        minutes,
        margin,
      );
    }
    if (order.detourKm <= 1.5 && order.pickupKm <= 2 && margin >= 15) {
      return StopFitResult(
        StopFitClassification.excellent,
        'Only a small detour from your journey, with time to spare.',
        minutes,
        margin,
      );
    }
    return StopFitResult(
      StopFitClassification.good,
      'Pickup fits your route with a manageable detour.',
      minutes,
      margin,
    );
  }
}
