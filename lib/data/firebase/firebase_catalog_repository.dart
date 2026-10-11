import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/vendor_model.dart';
import '../../models/product_model.dart';
import '../catalog_repository.dart';
import 'catalog_serialization.dart';

class FirebaseCatalogRepository implements CatalogRepository {
  FirebaseCatalogRepository(this.db);
  final FirebaseFirestore db;
  static const vendorLimit = 200;
  @override
  Stream<List<Vendor>> watchVendors(LatLng center) {
    // Query a conservative bounding box, then use exact circular distance locally.
    // Near the poles/dateline the latitude-only index avoids omitting wrapped points.
    var query = db
        .collection('vendors')
        .where('isPublished', isEqualTo: true)
        .where(
          'latitude',
          isGreaterThanOrEqualTo: math.max(-90, center.latitude - .19),
        )
        .where(
          'latitude',
          isLessThanOrEqualTo: math.min(90, center.latitude + .19),
        );
    final cosine = math.cos(center.latitude * math.pi / 180);
    final ratio = math.sin(21 / 6371) / cosine;
    if (ratio.abs() < 1) {
      final span = math.asin(ratio.abs()) * 180 / math.pi;
      final west = center.longitude - span, east = center.longitude + span;
      if (west >= -180 && east <= 180) {
        query = query
            .where('longitude', isGreaterThanOrEqualTo: west)
            .where('longitude', isLessThanOrEqualTo: east);
      }
    }
    return query
        .orderBy('latitude')
        .limit(vendorLimit)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CatalogSerialization.readShop(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Product>> watchProducts(String vendorId) => db
      .collection('vendors')
      .doc(vendorId)
      .collection('products')
      .where('isPublished', isEqualTo: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => CatalogSerialization.readProduct(vendorId, d.id, d.data()),
            )
            .toList(),
      );
}
