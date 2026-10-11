import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/navigation.dart';
import '../providers/cart_provider.dart';
import '../screens/cart/cart_screen.dart';

class CartButton extends StatelessWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().count;
    return IconButton(
      tooltip: 'Open cart',
      onPressed: () => openPage(context, const CartScreen()),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
