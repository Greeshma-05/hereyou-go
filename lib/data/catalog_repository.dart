import 'package:latlong2/latlong.dart';
import '../models/vendor_model.dart';
import '../models/product_model.dart';

abstract class CatalogRepository {
  Stream<List<Vendor>> watchVendors(LatLng center);
  Stream<List<Product>> watchProducts(String vendorId);
}

/// Startup failure must never silently replace live inventory with sample stock.
class UnavailableCatalogRepository implements CatalogRepository {
  const UnavailableCatalogRepository();

  @override
  Stream<List<Vendor>> watchVendors(LatLng center) =>
      Stream.error(StateError('Catalog service is unavailable.'));

  @override
  Stream<List<Product>> watchProducts(String vendorId) =>
      Stream.error(StateError('Catalog service is unavailable.'));
}
