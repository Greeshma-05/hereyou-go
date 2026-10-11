import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/catalog_repository.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/product_model.dart';
import 'package:route_rescue/models/vendor_model.dart';
import 'package:route_rescue/models/nearby_area.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/providers/catalog_provider.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'state_test.dart' show sampleJourney;

class LiveCatalogFixture implements CatalogRepository {
  final shops = StreamController<List<Vendor>>.broadcast();
  final inventory = StreamController<List<Product>>.broadcast();
  @override
  Stream<List<Vendor>> watchVendors(LatLng center) => shops.stream;
  @override
  Stream<List<Product>> watchProducts(String vendorId) => inventory.stream;
  Future<void> dispose() async {
    await shops.close();
    await inventory.close();
  }
}

const center = LatLng(9.92, 76.29);
const merchant = Vendor(
  id: 'merchant',
  name: 'Live test shop',
  category: Category.medicine,
  position: LatLng(9.974, 76.29),
  area: 'Public test address',
  preparationMinutes: 10,
  rating: 0,
  description: 'Owner-supplied inventory',
  isSample: false,
);
Product medicine({
  int stock = 10,
  int price = 2500,
  bool published = true,
  String expiry = '2030-12-31',
}) => Product(
  id: 'merchant/item',
  vendorId: 'merchant',
  name: 'Test tablet',
  category: Category.medicine,
  pricePaise: price,
  stock: stock,
  unit: '10 tablets',
  description: 'Label details',
  strength: '10 mg',
  dosageForm: 'Tablet',
  genericName: 'Test ingredient',
  brand: 'Test brand',
  manufacturer: 'Test maker',
  expiryDate: expiry,
  prescriptionRequired: true,
  published: published,
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'recovered catalog streams resubscribe to inventory and clear sync errors',
    () async {
      final source = LiveCatalogFixture();
      final catalog = CatalogProvider(repository: source)..setCenter(center);
      source.shops.add([merchant]);
      await flush();
      source.inventory.add([medicine()]);
      await flush();
      source.inventory.addError(StateError('temporary inventory error'));
      await flush();
      expect(catalog.error, isNotNull);
      source.inventory.add([medicine(stock: 9)]);
      await flush();
      expect(catalog.error, isNull);
      expect(catalog.products.single.stock, 9);
      source.shops.addError(StateError('temporary catalog error'));
      await flush();
      expect(catalog.products, isEmpty);
      source.shops.add([merchant]);
      await flush();
      source.inventory.add([medicine(stock: 11)]);
      await flush();
      expect(catalog.error, isNull);
      expect(catalog.products.single.stock, 11);
      catalog.dispose();
      await source.dispose();
    },
  );
  test(
    'unavailable production catalog stays empty instead of showing sample stock',
    () async {
      final catalog = CatalogProvider(
        repository: const UnavailableCatalogRepository(),
      )..setCenter(center);
      await flush();
      expect(catalog.products, isEmpty);
      expect(catalog.vendors, isEmpty);
      expect(catalog.loading, isFalse);
      expect(catalog.error, isNotNull);
      catalog.dispose();
    },
  );
  test(
    'live catalogs replace samples, sync medicine metadata and apply existing bus/train ranges',
    () async {
      final source = LiveCatalogFixture();
      final catalog = CatalogProvider(repository: source)..setCenter(center);
      expect(catalog.products, isEmpty);
      expect(catalog.vendors, isEmpty);
      source.shops.add([merchant]);
      await flush();
      source.inventory.add([medicine()]);
      await flush();
      expect(catalog.loading, isFalse);
      expect(catalog.vendors.single.isSample, false);
      final bus = NearbyArea(mode: JourneyMode.bus, devicePosition: center);
      final train = NearbyArea(mode: JourneyMode.train, devicePosition: center);
      expect(
        Catalog.searchProducts(
          'test ingredient',
          null,
          area: bus,
          products: catalog.products,
          vendors: catalog.vendors,
        ).single.strength,
        '10 mg',
      );
      expect(
        Catalog.searchVendorResults(
          'test maker',
          null,
          area: train,
          products: catalog.products,
          vendors: catalog.vendors,
        ).single.vendor.id,
        'merchant',
      );
      catalog.dispose();
      await source.dispose();
    },
  );
  test(
    'stock and price edits refresh cart, archived items cannot be ordered, and hiding a shop clears its products',
    () async {
      final source = LiveCatalogFixture();
      final catalog = CatalogProvider(repository: source)..setCenter(center);
      final cart = CartProvider(catalog: catalog);
      final orders = OrderProvider(catalog: catalog);
      source.shops.add([merchant]);
      await flush();
      source.inventory.add([medicine()]);
      await flush();
      expect(cart.add('merchant/item'), AddResult.added);
      source.inventory.add([medicine(stock: 0, price: 3000)]);
      await flush();
      expect(cart.items.single.product.pricePaise, 3000);
      expect(cart.add('merchant/item'), AddResult.outOfStock);
      source.inventory.add([]);
      await flush();
      expect(cart.items.single.product.name, 'Test tablet');
      expect(cart.add('merchant/item'), AddResult.unavailable);
      await expectLater(
        orders.place(cart.items, sampleJourney()),
        throwsStateError,
      );
      source.inventory.add([medicine(expiry: '2020-01-01')]);
      await flush();
      expect(catalog.products, isEmpty);
      source.inventory.add([medicine()]);
      await flush();
      source.shops.add([]);
      await flush();
      expect(catalog.products, isEmpty);
      cart.dispose();
      orders.dispose();
      catalog.dispose();
      await source.dispose();
    },
  );
  test(
    'moving location clears stale inventory and unavailable streams show an error',
    () async {
      final source = LiveCatalogFixture();
      final catalog = CatalogProvider(repository: source)..setCenter(center);
      source.shops.add([merchant]);
      await flush();
      source.inventory.add([medicine()]);
      await flush();
      catalog.setCenter(const LatLng(11, 77));
      expect(catalog.products, isEmpty);
      expect(catalog.vendors, isEmpty);
      source.shops.add([merchant]);
      await flush();
      expect(catalog.vendors, isEmpty);
      source.shops.addError(StateError('permission denied'));
      await flush();
      expect(catalog.error, contains('catalog could not connect'));
      catalog.dispose();
      await source.dispose();
    },
  );
}
