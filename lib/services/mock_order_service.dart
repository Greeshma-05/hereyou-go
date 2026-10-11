import 'dart:math';
import '../core/constants/demo_config.dart';
import '../data/catalog.dart';
import '../data/mock_journeys.dart';
import '../models/cart_item_model.dart';
import '../models/journey_model.dart';
import '../models/order_model.dart';
import '../models/vendor_model.dart';
import '../models/product_model.dart';

class MockOrderService {
  MockOrderService({
    Product? Function(String)? product,
    Vendor? Function(String)? vendor,
  }) : _product = product ?? Catalog.product,
       _vendor = vendor ?? Catalog.vendor;
  final Product? Function(String) _product;
  final Vendor? Function(String) _vendor;
  RescueOrder create({
    required List<CartItem> items,
    required Journey? journey,
  }) {
    if (journey == null || !journey.isValid) {
      throw StateError('Add your journey and delivery place first.');
    }
    if (journey.departure.isBefore(DateTime.now())) {
      throw StateError(
        'Your departure time has passed. Please update your journey.',
      );
    }
    final stops = journey.mode == JourneyMode.bus ? busStops : trainStops;
    if (!stops.any((s) => s.id == journey.pickup.id) &&
        journey.pickup.id != 'custom-${journey.mode.name}') {
      throw StateError('Choose a delivery place for this journey.');
    }
    if (items.isEmpty) throw StateError('Your cart is empty.');
    final vendorId = items.first.product.vendorId;
    final vendor = _vendor(vendorId);
    if (vendor == null || !vendor.available) {
      throw StateError('This shop is unavailable. Refresh the catalog.');
    }
    final seen = <String>{};
    // Rebuild every line from the trusted mock catalog, never from UI totals.
    final verified = items.map((item) {
      final product = _product(item.product.id);
      if (product == null || product.expired) {
        throw StateError('An item is no longer available. Review your cart.');
      }
      if (!seen.add(product.id) ||
          product.vendorId != vendorId ||
          item.quantity < 1 ||
          item.quantity > product.stock) {
        throw StateError(
          'Please check the quantities and vendor in your cart.',
        );
      }
      return CartItem(product, item.quantity);
    }).toList();
    final now = DateTime.now();
    return RescueOrder(
      reference:
          'HYG-${now.microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
      createdAt: now,
      vendorId: vendorId,
      vendorName: vendor.name,
      journey: journey,
      items: verified,
      deliveryFeePaise: DemoConfig.deliveryFeePaise,
      platformFeePaise: DemoConfig.platformFeePaise,
      verificationCode: (1000 + Random.secure().nextInt(9000)).toString(),
    );
  }
}
