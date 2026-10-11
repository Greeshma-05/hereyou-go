import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../data/catalog_repository.dart';
import '../data/mock_products.dart';
import '../data/mock_vendors.dart';
import '../models/product_model.dart';
import '../models/vendor_model.dart';

class CatalogProvider extends ChangeNotifier {
  CatalogProvider({this.repository}) {
    if (repository == null) {
      _vendors = List.of(mockVendors);
      for (final p in mockProducts) {
        _products[p.vendorId] = [...?_products[p.vendorId], p];
      }
    }
  }
  final CatalogRepository? repository;
  // Standalone widget tests can keep their explicit local catalog setup.
  static final _samples = CatalogProvider();
  static CatalogProvider of(BuildContext context, {bool listen = true}) =>
      Provider.of<CatalogProvider?>(context, listen: listen) ?? _samples;
  StreamSubscription<List<Vendor>>? _shopsSubscription;
  final _productSubscriptions = <String, StreamSubscription<List<Product>>>{};
  final _productTokens = <String, Object>{};
  final _inventoryErrors = <String>{};
  final _products = <String, List<Product>>{};
  final _pendingProducts = <String>{};
  List<Vendor> _vendors = [];
  LatLng? _center;
  bool _disposed = false;
  int _generation = 0;
  bool loading = false;
  String? _catalogError;
  String? get error =>
      _catalogError ??
      (_inventoryErrors.isEmpty
          ? null
          : 'Some shop inventory could not sync. Tap retry to reconnect.');
  bool truncated = false;
  bool get live => repository != null;
  List<Vendor> get vendors => List.unmodifiable(_vendors);
  List<Product> get products => List.unmodifiable(
    _products.values.expand((p) => p).where((p) => p.published && !p.expired),
  );
  Vendor? vendor(String id) => _vendors.where((v) => v.id == id).firstOrNull;
  Product? product(String id) => products.where((p) => p.id == id).firstOrNull;

  void setCenter(LatLng center, {bool retry = false}) {
    if (_disposed || repository == null || !retry && center == _center) return;
    _center = center;
    final generation = ++_generation;
    _shopsSubscription?.cancel();
    _clearInventory();
    _vendors = [];
    _catalogError = null;
    truncated = false;
    loading = true;
    _notify();
    _shopsSubscription = repository!
        .watchVendors(center)
        .listen(
          (all) {
            if (_disposed || generation != _generation) return;
            _catalogError = null;
            truncated = all.length >= 200;
            _vendors = all
                .where(
                  (v) =>
                      v.published &&
                      const Distance(roundResult: false)(center, v.position) <=
                          20001,
                )
                .toList();
            final ids = _vendors.map((v) => v.id).toSet();
            for (final id in _productSubscriptions.keys.toList()) {
              if (!ids.contains(id)) {
                _productSubscriptions.remove(id)?.cancel();
                _productTokens.remove(id);
                _products.remove(id);
                _pendingProducts.remove(id);
                _inventoryErrors.remove(id);
              }
            }
            for (final id in ids) {
              if (_productSubscriptions.containsKey(id)) continue;
              _pendingProducts.add(id);
              final token = Object();
              _productTokens[id] = token;
              _productSubscriptions[id] = repository!
                  .watchProducts(id)
                  .listen(
                    (items) {
                      if (_disposed ||
                          generation != _generation ||
                          _productTokens[id] != token ||
                          !_vendors.any((v) => v.id == id)) {
                        return;
                      }
                      _products[id] = items;
                      _inventoryErrors.remove(id);
                      _pendingProducts.remove(id);
                      loading = _pendingProducts.isNotEmpty;
                      _notify();
                    },
                    onError: (Object _) {
                      if (_disposed ||
                          generation != _generation ||
                          _productTokens[id] != token) {
                        return;
                      }
                      _products.remove(id);
                      _pendingProducts.remove(id);
                      loading = _pendingProducts.isNotEmpty;
                      _inventoryErrors.add(id);
                      _notify();
                    },
                  );
            }
            loading = _pendingProducts.isNotEmpty;
            _notify();
          },
          onError: (Object _) {
            if (_disposed || generation != _generation) return;
            _vendors = [];
            _clearInventory();
            loading = false;
            truncated = false;
            _catalogError =
                'Shop catalog could not connect. Check your connection and try again.';
            _notify();
          },
        );
  }

  void retry() {
    if (_center != null) setCenter(_center!, retry: true);
  }

  void _clearInventory() {
    for (final sub in _productSubscriptions.values) {
      sub.cancel();
    }
    _productSubscriptions.clear();
    _productTokens.clear();
    _products.clear();
    _pendingProducts.clear();
    _inventoryErrors.clear();
  }

  void _notify() {
    // Proxy-provider updates can occur during a parent build.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _shopsSubscription?.cancel();
    _clearInventory();
    super.dispose();
  }
}
