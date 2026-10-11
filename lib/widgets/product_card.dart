import 'package:flutter/material.dart';
import '../core/utils/formatters.dart';
import '../core/utils/navigation.dart';
import '../providers/catalog_provider.dart';
import '../models/product_model.dart';
import '../screens/product/product_screen.dart';
import 'cart_controls.dart';
import 'category_chip.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                openPage(context, ProductScreen(productId: product.id)),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryArtwork(product.category, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.unit,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (product.strength != null)
                        Text(
                          '${product.strength} · ${product.dosageForm}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      Text(
                        CatalogProvider.of(
                              context,
                            ).vendor(product.vendorId)?.name ??
                            'Shop unavailable',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 19),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      money(product.pricePaise),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      product.stock > 0
                          ? ((CatalogProvider.of(
                                      context,
                                    ).vendor(product.vendorId)?.available ==
                                    true)
                                ? '${product.stock} in stock'
                                : 'Shop currently closed')
                          : 'Out of stock',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              CartControls(product: product),
            ],
          ),
        ],
      ),
    ),
  );
}
