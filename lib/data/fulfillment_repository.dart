import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import 'courier_tracking_source.dart';
import 'firebase/cloud_serialization.dart';
import 'fulfillment_endpoint.dart';

abstract interface class LiveOrderRepository {
  Future<RescueOrder> placeLiveOrder(RescueOrder order);
  Future<void> cancelOrder(String reference);
  CourierTrackingSource get tracking;
}

/// All commercial mutations are checked by the same backend for all three apps.
class FulfillmentRepository {
  FulfillmentRepository(
    this.db,
    this.functions, {
    this.endpoint,
    this.emulated = false,
  });
  factory FulfillmentRepository.forApp(FirebaseApp app) {
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'asia-south1',
    );
    const emulated =
        kDebugMode && bool.fromEnvironment('FIREBASE_USE_EMULATORS');
    const configuredUrl = String.fromEnvironment('FULFILLMENT_URL');
    final endpoint = fulfillmentEndpoint(
      configuredUrl.isEmpty && !emulated
          ? 'https://here-you-go-orders.onrender.com/fulfillment'
          : configuredUrl,
      allowLocalHttp: emulated,
    );
    if (emulated && endpoint == null) {
      functions.useFunctionsEmulator(
        const String.fromEnvironment(
          'FIREBASE_EMULATOR_HOST',
          defaultValue: '10.0.2.2',
        ),
        const int.fromEnvironment(
          'FIREBASE_FUNCTIONS_EMULATOR_PORT',
          defaultValue: 5001,
        ),
      );
    }
    return FulfillmentRepository(
      FirebaseFirestore.instanceFor(app: app),
      functions,
      endpoint: endpoint,
      emulated: emulated,
    );
  }
  final FirebaseFirestore db;
  final FirebaseFunctions functions;
  final Uri? endpoint;
  final bool emulated;

  /// Basic contact details are owner-writable even without Cloud Functions.
  /// Assignment, presence and location remain controlled by the order service.
  Future<void> saveCourierProfile(
    String uid, {
    required String name,
    required String phone,
    required String vehicle,
  }) async {
    name = name.trim();
    phone = phone.trim();
    if (name.isEmpty || name.length > 80) {
      throw StateError('Enter your name (up to 80 characters).');
    }
    if (!RegExp(r'^[+0-9 ()-]{7,24}$').hasMatch(phone)) {
      throw StateError('Enter a valid phone number.');
    }
    if (!['Bicycle', 'Motorbike', 'Car'].contains(vehicle)) {
      throw StateError('Choose your delivery vehicle.');
    }
    final ref = db.doc('couriers/$uid');
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      final details = <String, dynamic>{
        'name': name,
        'phone': phone,
        'vehicle': vehicle,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (existing.exists) {
        transaction.update(ref, details);
      } else {
        transaction.set(ref, {
          ...details,
          'online': false,
          'activeOrderId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }, timeout: const Duration(seconds: 15));
  }

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      if (endpoint == null && !emulated) {
        throw StateError(
          'The order service is not connected in this app version. Install the connected release before placing an order.',
        );
      }
      // A free host can take a minute to wake. Never turn a timeout into a
      // preview; createOrder retries keep the same idempotent order reference.
      final options = HttpsCallableOptions(
        timeout: const Duration(seconds: 120),
      );
      final callable = endpoint == null
          ? functions.httpsCallable('fulfillment', options: options)
          : functions.httpsCallableFromUri(endpoint!, options: options);
      final result = await callable.call<dynamic>({...data, 'action': action});
      final value = Map<String, dynamic>.from(result.data as Map);
      if (value['error'] != null) throw StateError(value['error'] as String);
      return value;
    } on FirebaseFunctionsException catch (e) {
      throw StateError(switch (e.code) {
        'not-found' || 'unimplemented' =>
          'The order service is unavailable. Please retry after setup is complete.',
        'unavailable' || 'deadline-exceeded' =>
          'The order service could not be reached. Check your connection and retry.',
        _ => e.message ?? 'Could not complete this action. Try again.',
      });
    }
  }

  Future<RescueOrder> place(String uid, RescueOrder order) async {
    final trip = CloudSerialization.journey(order.journey);
    trip['departure'] = order.journey.departure.millisecondsSinceEpoch;
    await call('createOrder', {
      'reference': order.reference,
      'vendorId': order.vendorId,
      'journey': trip,
      'totalPaise': order.totalPaise,
      'items': order.items
          .map(
            (i) => {
              'productId': i.product.id.split('/').last,
              'quantity': i.quantity,
              'pricePaise': i.product.pricePaise,
            },
          )
          .toList(),
    });
    final saved = await db
        .doc('users/$uid/orders/${order.reference}')
        .get(const GetOptions(source: Source.server));
    return CloudSerialization.readOrder(saved.data()!);
  }

  Stream<List<Map<String, dynamic>>> ordersFor(String field, String uid) =>
      db.collection('orders').where(field, isEqualTo: uid).snapshots().map((s) {
        final orders = s.docs.map((d) => d.data()).toList();
        orders.sort(
          (a, b) => (b['createdAt'] as Timestamp).compareTo(
            a['createdAt'] as Timestamp,
          ),
        );
        return orders;
      });
  Stream<Map<String, dynamic>?> courier(String uid) =>
      db.doc('couriers/$uid').snapshots().map((d) => d.data());

  Future<List<Map<String, dynamic>>> nearbyCouriers(String reference) async {
    final result = await call('nearbyCouriers', {'reference': reference});
    return (result['partners'] as List)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }

  Future<void> assignCourier(String reference, String courierId) async {
    await call('assignCourier', {
      'reference': reference,
      'courierId': courierId,
    });
  }

  Future<void> transition(
    String reference,
    String status, {
    String? code,
  }) async {
    await call('transition', {
      'reference': reference,
      'status': status,
      'code': ?code,
    });
  }
}

class FirebaseCourierTracking implements CourierTrackingSource {
  FirebaseCourierTracking(this.db);
  final FirebaseFirestore db;
  @override
  bool get connected => true;
  @override
  Stream<CourierFix?> watch(String orderReference) =>
      db.doc('orderTracking/$orderReference').snapshots().map((doc) {
        final d = doc.data();
        if (d == null) return null;
        return CourierFix(
          position: LatLng(
            (d['latitude'] as num).toDouble(),
            (d['longitude'] as num).toDouble(),
          ),
          recordedAt: (d['recordedAt'] as Timestamp).toDate(),
          accuracyMeters: (d['accuracy'] as num?)?.toDouble(),
          name: d['name'] as String?,
        );
      });
}
