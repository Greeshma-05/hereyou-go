import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/cart_item_model.dart';
import '../../models/category.dart';
import '../../models/journey_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';

class CloudSerialization {
  static DateTime date(Object? value) => (value as Timestamp).toDate();
  static Map<String, dynamic> map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  static Map<String, dynamic> journey(Journey value) => {
    'mode': value.mode.name,
    'operatorName': value.operatorName,
    'boarding': value.boarding,
    'destination': value.destination,
    'departure': Timestamp.fromDate(value.departure),
    'pickup': {
      'id': value.pickup.id,
      'name': value.pickup.name,
      'latitude': value.pickup.position.latitude,
      'longitude': value.pickup.position.longitude,
      'instructions': value.pickup.instructions,
    },
  };
  static Journey readJourney(Map<String, dynamic> value) {
    final pickup = map(value['pickup']);
    return Journey(
      mode: JourneyMode.values.byName(value['mode'] as String),
      operatorName: value['operatorName'] as String,
      boarding: value['boarding'] as String,
      destination: value['destination'] as String,
      departure: date(value['departure']),
      pickup: PickupStop(
        pickup['id'] as String,
        pickup['name'] as String,
        LatLng(
          (pickup['latitude'] as num).toDouble(),
          (pickup['longitude'] as num).toDouble(),
        ),
        pickup['instructions'] as String,
      ),
    );
  }

  static Map<String, dynamic> product(Product p) => {
    'id': p.id,
    'vendorId': p.vendorId,
    'name': p.name,
    'category': p.category.name,
    'pricePaise': p.pricePaise,
    'stock': p.stock,
    'unit': p.unit,
    'description': p.description,
    'strength': p.strength,
    'dosageForm': p.dosageForm,
    'genericName': p.genericName,
    'brand': p.brand,
    'manufacturer': p.manufacturer,
    'expiryDate': p.expiryDate,
    'prescriptionRequired': p.prescriptionRequired,
  };
  static Product readProduct(Map<String, dynamic> p) => Product(
    id: p['id'] as String,
    vendorId: p['vendorId'] as String,
    name: p['name'] as String,
    category: Category.values.byName(p['category'] as String),
    pricePaise: p['pricePaise'] as int,
    stock: p['stock'] as int,
    unit: p['unit'] as String,
    description: p['description'] as String,
    strength: p['strength'] as String?,
    dosageForm: p['dosageForm'] as String?,
    genericName: p['genericName'] as String? ?? '',
    brand: p['brand'] as String? ?? '',
    manufacturer: p['manufacturer'] as String? ?? '',
    expiryDate: p['expiryDate'] as String? ?? '',
    prescriptionRequired: p['prescriptionRequired'] as bool? ?? false,
  );
  static Map<String, dynamic> order(RescueOrder o) => {
    'schemaVersion': 1,
    'reference': o.reference,
    'createdAt': Timestamp.fromDate(o.createdAt),
    'clientCreatedAt': Timestamp.fromDate(o.createdAt),
    'vendorId': o.vendorId,
    'vendorName': o.vendorName,
    'journey': journey(o.journey),
    'items': o.items
        .map((i) => {'product': product(i.product), 'quantity': i.quantity})
        .toList(),
    'deliveryFeePaise': o.deliveryFeePaise,
    'platformFeePaise': o.platformFeePaise,
    'totalPaise': o.totalPaise,
    'verificationCode': o.verificationCode,
    'status': o.status.name,
    'isPreview': o.isPreview,
  };
  static RescueOrder readOrder(Map<String, dynamic> o) => RescueOrder(
    reference: o['reference'] as String,
    createdAt: date(o['createdAt'] ?? o['clientCreatedAt']),
    vendorId: o['vendorId'] as String,
    vendorName: o['vendorName'] as String,
    journey: readJourney(map(o['journey'])),
    items: (o['items'] as List).map((item) {
      final i = map(item);
      return CartItem(readProduct(map(i['product'])), i['quantity'] as int);
    }).toList(),
    deliveryFeePaise: o['deliveryFeePaise'] as int,
    platformFeePaise: o['platformFeePaise'] as int,
    verificationCode: o['verificationCode'] as String,
    status: OrderStatus.values.byName(o['status'] as String),
    isPreview: o['isPreview'] as bool? ?? true,
    courierName: o['courierName'] as String?,
    pickupPosition: o['pickup'] is Map
        ? LatLng(
            (o['pickup']['latitude'] as num).toDouble(),
            (o['pickup']['longitude'] as num).toDouble(),
          )
        : null,
  );
}
