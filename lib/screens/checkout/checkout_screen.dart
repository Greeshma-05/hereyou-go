import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../providers/cart_provider.dart';
import '../../providers/journey_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/journey_card.dart';
import '../../widgets/price_summary.dart';
import '../journey/journey_screen.dart';
import '../orders/order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _submitting = false;
  String? _error;
  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final cart = context.read<CartProvider>();
      final order = await context.read<OrderProvider>().place(
        cart.items,
        context.read<JourneyProvider>().journey,
      );
      if (!mounted) return;
      cart.clear();
      // Remove checkout/cart routes so Android Back cannot submit this order again.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              OrderDetailScreen(reference: order.reference, justPlaced: true),
        ),
        (route) => route.isFirst,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      showMessage(context, error.message);
      setState(() {
        _submitting = false;
        _error = error.message.toString();
      });
    } catch (_) {
      if (!mounted) return;
      showMessage(
        context,
        'Could not create this order. Review your cart and try again.',
      );
      setState(() {
        _submitting = false;
        _error = 'Could not create this order. Review your cart and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final live = context.watch<OrderProvider>().liveFulfillment;
    final journey = context.watch<JourneyProvider>().journey;
    return Scaffold(
      appBar: AppBar(title: const Text('Review your pickup')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Notice(
                live
                    ? 'Your order will be sent to the shop. Pay the total in cash when your delivery arrives.'
                    : 'Preview checkout · No payment is collected and no order is sent to a shop.',
              ),
              const SectionHeading('Journey & delivery place'),
              if (journey != null)
                JourneyCard(journey: journey)
              else
                EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Add a journey first',
                  message:
                      'Add your bus or train, then type your delivery address and confirm its map pin.',
                  action: FilledButton(
                    onPressed: () => openPage(context, const JourneyScreen()),
                    child: const Text('Set up journey'),
                  ),
                ),
              if (journey != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Notice(journey.pickup.instructions),
                ),
              if (!cart.isEmpty) ...[
                SectionHeading(cart.vendorName),
                for (final item in cart.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity} × ${item.product.name}',
                          ),
                        ),
                        Text(money(item.subtotalPaise)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                PriceSummary(
                  subtotal: cart.subtotalPaise,
                  delivery: cart.deliveryFeePaise,
                  platform: cart.platformFeePaise,
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.science_outlined),
                  title: Text(
                    live ? 'Cash on delivery' : 'No payment required',
                  ),
                  subtitle: Text(
                    live
                        ? 'Pay ${money(cart.totalPaise)} on handover. No online payment is collected.'
                        : 'No card or bank details required.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Notice(_error!, warning: true),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: journey == null || _submitting ? null : _confirm,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _submitting
                          ? (live ? 'Sending order…' : 'Creating preview…')
                          : (live ? 'Place order' : 'Create preview'),
                    ),
                  ),
                ),
              ] else
                const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Your bag is empty',
                  message: 'Add essentials before confirming an order.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
