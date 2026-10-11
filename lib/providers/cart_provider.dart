import 'package:flutter/foundation.dart';
import '../core/constants/demo_config.dart';
import 'catalog_provider.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';

enum AddResult { added, outOfStock, differentVendor, unavailable }

class CartProvider extends ChangeNotifier {
  CartProvider({CatalogProvider? catalog})
    : _catalog = catalog ?? CatalogProvider(),
      _ownsCatalog = catalog == null {
    _catalog.addListener(_refresh);
  }
  final CatalogProvider _catalog;
  final bool _ownsCatalog;
  final _snapshots = <String, Product>{};
  String vendorName = 'Shop';
  void _refresh() {
    for (final id in _quantities.keys) {
      final current = _catalog.product(id);
      if (current != null) _snapshots[id] = current;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _catalog.removeListener(_refresh);
    if (_ownsCatalog) _catalog.dispose();
    super.dispose();
  }

  final Map<String, int> _quantities = {};
  List<CartItem> get items => List.unmodifiable(
    _quantities.entries.map((e) => CartItem(_snapshots[e.key]!, e.value)),
  );
  String? get vendorId => items.isEmpty ? null : items.first.product.vendorId;
  int quantity(String id) => _quantities[id] ?? 0;
  int get count => _quantities.values.fold(0, (a, b) => a + b);
  bool get isEmpty => _quantities.isEmpty;
  int get subtotalPaise => items.fold(0, (a, b) => a + b.subtotalPaise);
  int get deliveryFeePaise => isEmpty ? 0 : DemoConfig.deliveryFeePaise;
  int get platformFeePaise => isEmpty ? 0 : DemoConfig.platformFeePaise;
  int get totalPaise => subtotalPaise + deliveryFeePaise + platformFeePaise;

  // Accept only catalog IDs; callers cannot inject a price or stock value.
  AddResult add(String id) {
    final product = _catalog.product(id);
    if (product == null) return AddResult.unavailable;
    if (_catalog.vendor(product.vendorId)?.available != true) {
      return AddResult.unavailable;
    }
    if (quantity(id) >= product.stock) return AddResult.outOfStock;
    if (vendorId != null && vendorId != product.vendorId) {
      return AddResult.differentVendor;
    }
    _snapshots[id] = product;
    vendorName = _catalog.vendor(product.vendorId)!.name;
    _quantities[id] = quantity(id) + 1;
    notifyListeners();
    return AddResult.added;
  }

  void decrease(String id) {
    if (quantity(id) <= 1) {
      _quantities.remove(id);
    } else {
      _quantities[id] = quantity(id) - 1;
    }
    notifyListeners();
  }

  void remove(String id) {
    _quantities.remove(id);
    notifyListeners();
  }

  void clear() {
    _quantities.clear();
    _snapshots.clear();
    notifyListeners();
  }
}
