import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/cart_controls.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/common.dart';
import '../../widgets/price_summary.dart';
import '../checkout/checkout_screen.dart';
import '../explore/explore_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Your travel bag')),
      body: SafeArea(
        child: PageBody(
          child: cart.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'A little room for essentials',
                  message:
                      'Choose a shop and add what you need for the journey.',
                  action: FilledButton(
                    onPressed: () => openPage(
                      context,
                      const ExploreScreen(initialMap: false),
                    ),
                    child: const Text('Find essentials'),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.vendorName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('One shop. One coordinated pickup.'),
                    const SizedBox(height: 20),
                    for (final item in cart.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CategoryArtwork(
                                      item.product.category,
                                      size: 52,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          Text(
                                            '${money(item.product.pricePaise)} each · ${item.product.unit}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove ${item.product.name}',
                                      onPressed: () =>
                                          cart.remove(item.product.id),
                                      icon: const Icon(Icons.close, size: 19),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    CartControls(product: item.product),
                                    const Spacer(),
                                    Text(
                                      money(item.subtotalPaise),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    PriceSummary(
                      subtotal: cart.subtotalPaise,
                      delivery: cart.deliveryFeePaise,
                      platform: cart.platformFeePaise,
                    ),
                    const SizedBox(height: 20),
                    Notice(
                      context.watch<OrderProvider>().liveFulfillment
                          ? 'Orders are sent to the shop. Pay cash on delivery.'
                          : 'Preview checkout. No real payment, order or delivery will be made.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            openPage(context, const CheckoutScreen()),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue to checkout'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
