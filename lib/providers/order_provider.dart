import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/user_repository.dart';
import '../data/fulfillment_repository.dart';
import '../data/courier_tracking_source.dart';
import '../models/cart_item_model.dart';
import '../models/journey_model.dart';
import '../models/order_model.dart';
import '../services/mock_order_service.dart';
import 'catalog_provider.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({this.repository, this.uid, CatalogProvider? catalog})
    : _service = MockOrderService(
        product: catalog?.product,
        vendor: catalog?.vendor,
      ) {
    loading = cloudBacked;
    if (cloudBacked) {
      _subscription = repository!
          .watchOrders(uid!)
          .listen(
            (values) {
              _orders = values;
              loading = false;
              error = null;
              _notify();
            },
            onError: (Object failure) {
              loading = false;
              error = 'Order history could not sync. Check your connection.';
              _notify();
            },
          );
    }
  }
  final UserRepository? repository;
  final String? uid;
  final MockOrderService _service;
  StreamSubscription<List<RescueOrder>>? _subscription;
  List<RescueOrder> _orders = [];
  List<RescueOrder> get orders => List.unmodifiable(_orders);
  bool get liveFulfillment => cloudBacked && repository is LiveOrderRepository;
  CourierTrackingSource? get tracking =>
      liveFulfillment ? (repository as LiveOrderRepository).tracking : null;
  Future<void> cancelOrder(String reference) async {
    if (liveFulfillment) {
      await (repository as LiveOrderRepository).cancelOrder(reference);
    }
  }

  RescueOrder? _pendingOrder;
  String? _pendingSignature;
  bool get cloudBacked => uid != null && repository != null;
  bool loading = false;
  bool _disposed = false;
  String? error;
  Future<RescueOrder>? _placing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  RescueOrder byReference(String id) =>
      _orders.firstWhere((o) => o.reference == id);
  Future<RescueOrder> place(List<CartItem> items, Journey? journey) {
    // Repeated taps share the same in-flight write and order identifier.
    return _placing ??= _place(
      List.of(items),
      journey,
    ).whenComplete(() => _placing = null);
  }

  Future<RescueOrder> _place(List<CartItem> items, Journey? journey) async {
    final signature =
        '${items.map((i) => '${i.product.id}:${i.quantity}:${i.product.pricePaise}').join('|')}|${journey?.mode}|${journey?.operatorName}|${journey?.boarding}|${journey?.destination}|${journey?.departure}|${journey?.pickup.name}|${journey?.pickup.position}|${journey?.pickup.instructions}';
    // Keep the reference after an uncertain network response: retry is idempotent.
    if (_pendingSignature != signature || _pendingOrder == null) {
      _pendingOrder = _service.create(items: items, journey: journey);
      _pendingSignature = signature;
    }
    var order = _pendingOrder!;
    if (liveFulfillment) {
      order = await (repository as LiveOrderRepository).placeLiveOrder(order);
    } else if (cloudBacked) {
      await repository!.saveOrder(uid!, order);
    }
    _pendingOrder = null;
    _pendingSignature = null;
    if (!_disposed) {
      if (!_orders.any((o) => o.reference == order.reference)) {
        _orders.insert(0, order);
      }
      _notify();
    }
    return order;
  }

  void advance(String reference) {
    // Cloud order status belongs to a trusted backend, never to the customer.
    if (cloudBacked) return;
    final index = _orders.indexWhere((o) => o.reference == reference);
    if (index < 0 || _orders[index].status == OrderStatus.handedOver) return;
    final order = _orders[index];
    _orders[index] = order.withStatus(
      OrderStatus.previewStages[OrderStatus.previewStages.indexOf(
            order.status,
          ) +
          1],
    );
    _notify();
  }

  void clear() {
    _orders.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
