import 'package:flutter/material.dart';
import '../../core/constants/demo_config.dart';
import '../../providers/catalog_provider.dart';
import '../../models/category.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';
import '../../widgets/vendor_card.dart';

class VendorScreen extends StatelessWidget {
  const VendorScreen({super.key, required this.vendorId});
  final String vendorId;
  @override
  Widget build(BuildContext context) {
    final catalog = CatalogProvider.of(context);
    final vendor = catalog.vendor(vendorId);
    if (vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shop unavailable')),
        body: const Center(
          child: Text('This shop is no longer available in your area.'),
        ),
      );
    }
    final products = catalog.products.where((p) => p.vendorId == vendorId);
    return Scaffold(
      appBar: AppBar(title: Text('Meet your stop'), actions: [CartButton()]),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: categoryColor(context, vendor.category),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(categoryIcon(vendor.category), size: 40),
                    SizedBox(height: 20),
                    Text(
                      vendor.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: 8),
                    Text(vendor.description),
                  ],
                ),
              ),
              SizedBox(height: 16),
              VendorCard(vendor: vendor, onTap: () {}),
              SizedBox(height: 16),
              Notice(
                vendor.isSample && vendor.category == Category.medicine
                    ? DemoConfig.healthcareNotice
                    : vendor.isSample
                    ? 'Mock vendor · prices, ratings, preparation times and availability are sample data.'
                    : 'Catalog supplied by this vendor. Checkout remains a preview; no payment or delivery is placed.',
              ),
              if (!vendor.available)
                Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Notice(
                    'This shop is closed. Browse its catalog or choose another vendor.',
                    warning: true,
                  ),
                ),
              SectionHeading('Pick your essentials'),
              if (products.isEmpty)
                const Notice('This shop has no published products yet.'),
              for (final product in products)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ProductCard(product: product),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
