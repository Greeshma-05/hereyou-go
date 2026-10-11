import 'package:latlong2/latlong.dart';
import 'cart_item_model.dart';
import 'journey_model.dart';

enum OrderStatus {
  placed('Order placed', 'Your order has been created.'),
  confirmed('Vendor confirmation', 'The vendor has accepted your order.'),
  preparing('Preparing order', 'Your essentials are being prepared.'),
  assigned(
    'Delivery partner assigned',
    'A delivery partner has been assigned.',
  ),
  ready('Ready for handover', 'Your order is ready for pickup from the shop.'),
  pickedUp('On the way', 'Your delivery partner has collected your order.'),
  handedOver('Order handed over', 'Have a comfortable journey!'),
  cancelled('Cancelled', 'This order was cancelled.');

  const OrderStatus(this.label, this.description);
  static List<OrderStatus> get previewStages =>
      values.where((s) => s != cancelled && s != pickedUp).toList();
  static List<OrderStatus> get progressStages =>
      values.where((s) => s != cancelled).toList();
  final String label;
  final String description;
}

class RescueOrder {
  RescueOrder({
    required this.reference,
    required this.createdAt,
    required this.vendorId,
    this.vendorName = 'Shop',
    required this.journey,
    required List<CartItem> items,
    required this.deliveryFeePaise,
    required this.platformFeePaise,
    required this.verificationCode,
    this.status = OrderStatus.placed,
    this.isPreview = true,
    this.courierName,
    this.pickupPosition,
  }) : items = List.unmodifiable(items);
  final String reference;
  final DateTime createdAt;
  final String vendorId;
  final String vendorName;
  final Journey journey;
  final List<CartItem> items;
  final int deliveryFeePaise;
  final int platformFeePaise;
  final String verificationCode;
  final OrderStatus status;
  final bool isPreview;
  final String? courierName;
  final LatLng? pickupPosition;
  int get subtotalPaise =>
      items.fold(0, (total, item) => total + item.subtotalPaise);
  int get totalPaise => subtotalPaise + deliveryFeePaise + platformFeePaise;
  RescueOrder withStatus(OrderStatus next) => RescueOrder(
    reference: reference,
    createdAt: createdAt,
    vendorId: vendorId,
    vendorName: vendorName,
    journey: journey,
    items: items,
    deliveryFeePaise: deliveryFeePaise,
    platformFeePaise: platformFeePaise,
    verificationCode: verificationCode,
    status: next,
    isPreview: isPreview,
    courierName: courierName,
    pickupPosition: pickupPosition,
  );
}
