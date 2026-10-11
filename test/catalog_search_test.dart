import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/product_model.dart';
import 'package:route_rescue/models/vendor_model.dart';

Vendor shop(String id, {bool open = true}) => Vendor(
  id: id,
  name: 'Shop $id',
  category: Category.medicine,
  position: const LatLng(9.97, 76.29),
  area: 'Kochi',
  preparationMinutes: 10,
  rating: 4.5,
  available: open,
  description: '',
);
Product supply(
  String id,
  String vendor, {
  int stock = 5,
  String name = 'Saline nasal spray',
}) => Product(
  id: id,
  vendorId: vendor,
  name: name,
  category: Category.medicine,
  pricePaise: 8500,
  stock: stock,
  unit: '20 ml',
  description: '',
  strength: '0.65%',
  dosageForm: 'Nasal spray',
);

void main() {
  test('open shops with matching stock outrank sold-out and closed shops', () {
    final vendors = [
      shop('sold-out'),
      shop('closed', open: false),
      shop('available'),
    ];
    final products = [
      supply('empty', 'sold-out', stock: 0),
      supply('closed-stock', 'closed'),
      supply('ready', 'available'),
      // Unrelated stock must not boost the sold-out shop for the query.
      supply('unrelated', 'sold-out', name: 'Bandages', stock: 100),
    ];
    final results = Catalog.searchVendorResults(
      'saline',
      Category.medicine,
      products: products,
      vendors: vendors,
    );
    expect(results.map((r) => r.vendor.id), [
      'available',
      'sold-out',
      'closed',
    ]);
    expect(results.map((r) => r.canSupply), [true, false, false]);
    expect(results[1].inStock, isEmpty);
    expect(
      Catalog.searchProducts(
        'saline',
        null,
        products: products,
        vendors: vendors,
      ).map((p) => p.id),
      ['ready', 'empty', 'closed-stock'],
    );
  });
  test('more matching available items rank first, with deterministic ties', () {
    final vendors = [shop('one'), shop('two'), shop('tie')];
    final products = [
      supply('1', 'one'),
      supply('2', 'two'),
      supply('3', 'two'),
      supply('4', 'tie'),
    ];
    expect(
      Catalog.searchVendorResults(
        'saline',
        null,
        products: products,
        vendors: vendors,
      ).map((r) => r.vendor.id),
      ['two', 'one', 'tie'],
    );
  });
  test(
    'medicine names, strengths, categories and abbreviations agree across results',
    () {
      for (final query in ['  NASAL  spray ', '0.65%', 'spray saline']) {
        expect(Catalog.searchProducts(query, null).single.id, 'saline');
        final result = Catalog.searchVendorResults(query, null).single;
        expect(result.vendor.id, 'pharmacy');
        expect(result.canSupply, isFalse);
      }
      expect(Catalog.searchProducts('ors', null).single.id, 'ors');
      expect(Catalog.searchVendorResults('ors', null).single.canSupply, isTrue);
      expect(Catalog.searchProducts('medicine', null).length, 3);
      expect(Catalog.searchProducts('food', Category.medicine), isEmpty);
      expect(Catalog.searchVendorResults('food', Category.medicine), isEmpty);
      expect(Catalog.searchVendorResults('unlisted medicine', null), isEmpty);
      expect(Catalog.searchVendorResults('  ', null), isNotEmpty);
    },
  );
}
