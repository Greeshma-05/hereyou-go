import 'package:flutter/material.dart';
import '../../core/constants/demo_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../providers/catalog_provider.dart';
import '../../models/category.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/cart_controls.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/common.dart';
import '../vendor/vendor_screen.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, required this.productId});
  final String productId;
  @override
  Widget build(BuildContext context) {
    final catalog = CatalogProvider.of(context);
    final product = catalog.product(productId);
    final vendor = product == null ? null : catalog.vendor(product.vendorId);
    if (product == null || vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product unavailable')),
        body: const Center(
          child: Text(
            'This product is no longer available. Please browse the current catalog.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('A little essential'),
        actions: [CartButton()],
      ),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 38),
                decoration: BoxDecoration(
                  color: categoryColor(context, product.category),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Center(
                  child: CategoryArtwork(product.category, size: 120),
                ),
              ),
              SizedBox(height: 24),
              StatusBadge(text: 'JOURNEY ESSENTIAL'),
              SizedBox(height: 14),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 6),
              Text('${product.category.label} · ${product.unit}'),
              if (product.strength != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('${product.strength} · ${product.dosageForm}'),
                ),
              if (product.genericName.isNotEmpty)
                Text('Generic name: ${product.genericName}'),
              if (product.brand.isNotEmpty) Text('Brand: ${product.brand}'),
              if (product.manufacturer.isNotEmpty)
                Text('Manufacturer: ${product.manufacturer}'),
              if (product.expiryDate.isNotEmpty)
                Text('Expiry: ${product.expiryDate}'),
              if (product.prescriptionRequired)
                const Notice(
                  'Prescription required',
                  icon: Icons.description_outlined,
                ),
              SizedBox(height: 18),
              Text(product.description),
              SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.storefront_outlined),
                title: Text(vendor.name),
                subtitle: Text(
                  '${vendor.preparationMinutes} min preparation · ${vendor.available ? 'Open' : 'Closed'}',
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () =>
                    openPage(context, VendorScreen(vendorId: vendor.id)),
              ),
              Divider(),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          money(product.pricePaise),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          '${product.stock} in stock',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  CartControls(product: product),
                ],
              ),
              SizedBox(height: 24),
              Notice(
                vendor.isSample && product.category == Category.medicine
                    ? DemoConfig.healthcareNotice
                    : vendor.isSample
                    ? 'Illustrative product and unverified sample inventory. No real purchase or fulfillment takes place.'
                    : 'Details and stock are supplied by the vendor. Checkout is a preview; no payment or fulfillment takes place.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
