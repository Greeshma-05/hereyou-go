import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'package:route_rescue/models/vendor_model.dart';
import 'package:route_rescue/models/product_model.dart';

class MerchantState extends ChangeNotifier {
  MerchantState(this.repository, this.uid) {
    connect();
  }
  final MerchantRepository repository;
  final String uid;
  Vendor? shop;
  List<Product> products = [];
  bool loading = true;
  bool inventoryLoading = true;
  bool _disposed = false;
  String? error;
  StreamSubscription<Vendor?>? _shopSub;
  StreamSubscription<List<Product>>? _productsSub;
  void connect() {
    _shopSub?.cancel();
    _productsSub?.cancel();
    error = null;
    loading = true;
    inventoryLoading = true;
    _shopSub = repository
        .watchShop(uid)
        .listen(
          (value) {
            if (_disposed) return;
            shop = value;
            loading = false;
            notifyListeners();
          },
          onError: (Object e) {
            if (_disposed) return;
            error = merchantError(e);
            loading = false;
            notifyListeners();
          },
        );
    _productsSub = repository
        .watchProducts(uid)
        .listen(
          (value) {
            if (_disposed) return;
            products = value;
            inventoryLoading = false;
            notifyListeners();
          },
          onError: (Object e) {
            if (_disposed) return;
            error = merchantError(e);
            inventoryLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _shopSub?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }
}

String merchantError(Object e) {
  if (e is FirebaseException) {
    return switch (e.code) {
      'permission-denied' =>
        'This account cannot access the shop catalog yet. Contact the project owner to enable vendor access.',
      'unavailable' || 'network-request-failed' =>
        'Check your connection and try again. Your changes have not been confirmed.',
      'email-already-in-use' =>
        'This email already has an account. Use Log in, including if you registered in the customer app.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use a stronger password with at least 8 characters.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => 'Could not save your changes. Check your connection and try again.',
    };
  }
  return 'Could not complete this action. Please try again.';
}
