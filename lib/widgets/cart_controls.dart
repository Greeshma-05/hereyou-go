import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/navigation.dart';
import '../models/product_model.dart';
import '../providers/catalog_provider.dart';
import '../providers/cart_provider.dart';

Future<void> addToCart(BuildContext context, Product product) async {
  final cart = context.read<CartProvider>();
  final result = cart.add(product.id);
  switch (result) {
    case AddResult.added:
      return;
    case AddResult.outOfStock:
      showMessage(context, 'You have reached the available stock.');
    case AddResult.unavailable:
      showMessage(context, 'This shop or product is currently unavailable.');
    case AddResult.differentVendor:
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Start a new cart?'),
          content: Text(
            'Each order comes from one vendor. Starting a new cart will remove your current items.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Keep current cart'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Start new cart'),
            ),
          ],
        ),
      );
      if (replace == true && context.mounted) {
        cart.clear();
        cart.add(product.id);
      }
  }
}

class CartControls extends StatelessWidget {
  const CartControls({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.quantity(product.id);
    if (quantity == 0) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: Size(76, 40)),
        onPressed:
            product.stock == 0 ||
                (CatalogProvider.of(
                      context,
                    ).vendor(product.vendorId)?.available !=
                    true)
            ? null
            : () => addToCart(context, product),
        child: Text(
          product.stock == 0
              ? 'Sold out'
              : (CatalogProvider.of(
                      context,
                    ).vendor(product.vendorId)?.available !=
                    true)
              ? 'Closed'
              : 'Add +',
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.colors(context).tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease ${product.name}',
            onPressed: () => cart.decrease(product.id),
            icon: Icon(Icons.remove, size: 18),
          ),
          Text('$quantity', style: TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            tooltip: 'Increase ${product.name}',
            onPressed: quantity >= product.stock
                ? null
                : () => addToCart(context, product),
            icon: Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
