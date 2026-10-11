import '../models/category.dart';
import '../models/product_model.dart';
import '../models/vendor_model.dart';
import '../models/nearby_area.dart';
import 'mock_products.dart';
import 'mock_vendors.dart';

class VendorSearchResult {
  const VendorSearchResult({required this.vendor, required this.products});
  final Vendor vendor;
  final List<Product> products;
  List<Product> get inStock => products.where((p) => p.stock > 0).toList();
  bool get canSupply => vendor.available && inStock.isNotEmpty;
  int get availabilityRank => canSupply ? 0 : (vendor.available ? 1 : 2);
}

class Catalog {
  static Product product(String id) =>
      mockProducts.firstWhere((p) => p.id == id);
  static Vendor vendor(String id) => mockVendors.firstWhere((v) => v.id == id);
  static Vendor? vendorOrNull(String id) =>
      mockVendors.where((v) => v.id == id).firstOrNull;

  static bool _matches(String query, String text) {
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    final searchable = text.toLowerCase();
    return terms.every(searchable.contains);
  }

  static String _productText(Product p, Vendor v) =>
      '${p.name} ${p.strength ?? ''} ${p.dosageForm ?? ''} '
      '${p.genericName} ${p.brand} ${p.manufacturer} ${p.category.label} ${v.name} ${_aliases[p.id] ?? ''}';

  // Catalog synonyms only: search never recommends medicine substitutions.
  static const _aliases = {
    'ors': 'ORS',
    'chips': 'snack snacks',
    'meal': 'lunch dinner rice',
    'idli': 'breakfast',
    'bandages': 'first aid band aid',
    'water': 'drink drinks',
  };

  static List<Product> searchProducts(
    String query,
    Category? category, {
    List<Product> products = mockProducts,
    List<Vendor> vendors = mockVendors,
    NearbyArea? area,
  }) {
    Vendor shop(Product p) => vendors.firstWhere((v) => v.id == p.vendorId);
    final matches = products
        .where(
          (p) =>
              (area == null || area.contains(shop(p).position)) &&
              (category == null || p.category == category) &&
              _matches(query, _productText(p, shop(p))),
        )
        .toList();
    int rank(Product p) => !shop(p).available ? 2 : (p.stock > 0 ? 0 : 1);
    matches.sort((a, b) {
      final availability = rank(a).compareTo(rank(b));
      if (availability != 0) return availability;
      if (area != null) {
        final distance = area
            .distanceKm(shop(a).position)
            .compareTo(area.distanceKm(shop(b).position));
        if (distance != 0) return distance;
      }
      return products.indexOf(a).compareTo(products.indexOf(b));
    });
    return matches;
  }

  static List<VendorSearchResult> searchVendorResults(
    String query,
    Category? category, {
    List<Product> products = mockProducts,
    List<Vendor> vendors = mockVendors,
    NearbyArea? area,
  }) {
    final results = <VendorSearchResult>[];
    for (final v in vendors) {
      if (area != null && !area.contains(v.position)) continue;
      final matches = products
          .where(
            (p) =>
                p.vendorId == v.id &&
                (category == null || p.category == category) &&
                _matches(query, _productText(p, v)),
          )
          .toList();
      final vendorMatches =
          (category == null || v.category == category) &&
          _matches(query, '${v.name} ${v.category.label}');
      if (matches.isNotEmpty || vendorMatches) {
        results.add(VendorSearchResult(vendor: v, products: matches));
      }
    }
    results.sort((a, b) {
      final availability = a.availabilityRank.compareTo(b.availabilityRank);
      if (availability != 0) return availability;
      if (query.trim().isNotEmpty && a.canSupply && b.canSupply) {
        final stock = b.inStock.length.compareTo(a.inStock.length);
        if (stock != 0) return stock;
      }
      if (area != null) {
        final distance = area
            .distanceKm(a.vendor.position)
            .compareTo(area.distanceKm(b.vendor.position));
        if (distance != 0) return distance;
      }
      return vendors.indexOf(a.vendor).compareTo(vendors.indexOf(b.vendor));
    });
    return results;
  }

  static List<Vendor> searchVendors(String query, Category? category) =>
      searchVendorResults(
        query,
        category,
      ).map((result) => result.vendor).toList();
}
