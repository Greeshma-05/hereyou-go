import 'delivery_status.dart';
import 'route_stop.dart';

class OrderItem {
  const OrderItem(this.name, this.quantity);
  final String name;
  final int quantity;
}

class DeliveryRequest {
  const DeliveryRequest({
    required this.id,
    required this.traveler,
    required this.items,
    required this.category,
    required this.pickup,
    required this.handover,
    required this.pickupKm,
    required this.detourKm,
    required this.waitMinutes,
    required this.availableMinutes,
    required this.rewardPaise,
    required this.demoCode,
    this.matchesRoute = true,
    this.status = DeliveryStatus.pending,
  });
  final String id;
  final String traveler;
  final List<OrderItem> items;
  final String category;
  final RouteStop pickup;
  final RouteStop handover;
  final double pickupKm;
  final double detourKm;
  final int waitMinutes;
  final int availableMinutes;
  final int rewardPaise;
  final String demoCode;
  final bool matchesRoute;
  final DeliveryStatus status;
  String get routeContext => matchesRoute
      ? 'Bengaluru → Mysuru · Rail journey'
      : 'Bengaluru → Tumakuru · Different corridor';
  String get itemSummary =>
      items.map((item) => '${item.quantity}× ${item.name}').join(' · ');

  DeliveryRequest withStatus(DeliveryStatus next) => DeliveryRequest(
    id: id,
    traveler: traveler,
    items: items,
    category: category,
    pickup: pickup,
    handover: handover,
    pickupKm: pickupKm,
    detourKm: detourKm,
    waitMinutes: waitMinutes,
    availableMinutes: availableMinutes,
    rewardPaise: rewardPaise,
    demoCode: demoCode,
    matchesRoute: matchesRoute,
    status: next,
  );
}
