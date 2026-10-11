import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/category.dart';
import '../../models/product_model.dart';
import '../../models/vendor_model.dart';

class CatalogSerialization {
  static Map<String, dynamic> shop(Vendor v) => {
    'schemaVersion': 1,
    'ownerUid': v.id,
    'name': v.name,
    'category': v.category.name,
    'address': v.area,
    'latitude': v.position.latitude,
    'longitude': v.position.longitude,
    'description': v.description,
    'preparationMinutes': v.preparationMinutes,
    'isOpen': v.available,
    'isPublished': v.published,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  static Vendor readShop(String uid, Map<String, dynamic> d) => Vendor(
    id: uid,
    name: d['name'] as String,
    category: Category.values.byName(d['category'] as String),
    position: LatLng(
      (d['latitude'] as num).toDouble(),
      (d['longitude'] as num).toDouble(),
    ),
    area: d['address'] as String,
    description: d['description'] as String,
    preparationMinutes: d['preparationMinutes'] as int,
    rating: 0,
    available: d['isOpen'] as bool,
    published: d['isPublished'] as bool,
    isSample: false,
  );
  static Map<String, dynamic> product(Product p) => {
    'schemaVersion': 1,
    'vendorId': p.vendorId,
    'name': p.name,
    'category': p.category.name,
    'pricePaise': p.pricePaise,
    'stock': p.stock,
    'unit': p.unit,
    'description': p.description,
    'strength': p.strength ?? '',
    'dosageForm': p.dosageForm ?? '',
    'genericName': p.genericName,
    'brand': p.brand,
    'manufacturer': p.manufacturer,
    'expiryDate': p.expiryDate,
    'prescriptionRequired': p.prescriptionRequired,
    'isPublished': p.published,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  static Product readProduct(String uid, String id, Map<String, dynamic> d) =>
      Product(
        id: '$uid/$id',
        vendorId: uid,
        name: d['name'] as String,
        category: Category.values.byName(d['category'] as String),
        pricePaise: d['pricePaise'] as int,
        stock: d['stock'] as int,
        unit: d['unit'] as String,
        description: d['description'] as String,
        strength: (d['strength'] as String).isEmpty
            ? null
            : d['strength'] as String,
        dosageForm: (d['dosageForm'] as String).isEmpty
            ? null
            : d['dosageForm'] as String,
        genericName: d['genericName'] as String,
        brand: d['brand'] as String,
        manufacturer: d['manufacturer'] as String,
        expiryDate: d['expiryDate'] as String,
        prescriptionRequired: d['prescriptionRequired'] as bool,
        published: d['isPublished'] as bool,
      );
}
