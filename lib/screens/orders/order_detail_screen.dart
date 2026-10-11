import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/journey_card.dart';
import '../../widgets/price_summary.dart';
import 'delivery_map_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.reference,
    this.justPlaced = false,
  });
  final String reference;
  final bool justPlaced;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final order = provider.byReference(reference);
    final complete = order.status == OrderStatus.handedOver;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          order.isPreview
              ? (justPlaced ? 'Preview created' : 'Preview details')
              : (justPlaced ? 'Order sent to shop' : 'Order details'),
        ),
      ),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: AppTheme.colors(context).tint,
                      child: Icon(
                        order.isPreview
                            ? Icons.science_outlined
                            : Icons.receipt_long_outlined,
                        color: AppTheme.colors(context).accent,
                        size: 42,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      order.isPreview
                          ? 'This is a preview.'
                          : order.status == OrderStatus.cancelled
                          ? 'Your order was cancelled.'
                          : complete
                          ? 'All set. Travel well!'
                          : order.status == OrderStatus.placed
                          ? 'Waiting for the shop to accept.'
                          : 'Your order is in progress.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      order.reference,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 14),
                    StatusBadge(
                      text: order.isPreview
                          ? 'PREVIEW · NOT SENT TO SHOP'
                          : '${order.status.label.toUpperCase()} · CASH ON DELIVERY',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (order.isPreview) ...[
                const Notice(
                  'No shop or delivery partner received this preview. Sign in and place a new order to request delivery. No payment is due.',
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your delivery route',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${order.vendorName} → ${order.journey.pickup.name}',
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  DeliveryMapScreen(reference: reference),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('View delivery map'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeading(
                order.isPreview ? 'Preview progress' : 'Order progress',
              ),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      for (final status
                          in (order.status == OrderStatus.cancelled
                              ? [OrderStatus.cancelled]
                              : (order.isPreview
                                        ? OrderStatus.previewStages
                                        : OrderStatus.progressStages)
                                    .where(
                                      (s) =>
                                          order.isPreview ||
                                          s != OrderStatus.assigned,
                                    )))
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                status.index <= order.status.index
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: status.index <= order.status.index
                                    ? AppTheme.colors(context).accent
                                    : AppTheme.colors(context).muted,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.isPreview
                                          ? 'Preview: ${status.label}'
                                          : status.label,
                                      style: TextStyle(
                                        fontWeight: status == order.status
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    if (status == order.status)
                                      Text(
                                        order.isPreview
                                            ? 'Simulated stage only. No live order was sent.'
                                            : status.description,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Notice(
                order.status == OrderStatus.cancelled
                    ? 'No payment is due for this cancelled order.'
                    : !order.isPreview
                    ? (order.courierName == null
                          ? 'Waiting for a nearby delivery partner. Order progress updates automatically.'
                          : 'Delivery partner: ${order.courierName}. Progress and location update while your partner is online.')
                    : 'This saved preview has no live delivery tracking.',
              ),
              SizedBox(height: 14),
              if (order.isPreview && !complete && !provider.cloudBacked)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => provider.advance(reference),
                    icon: Icon(Icons.fast_forward_outlined),
                    label: Text('Next preview stage'),
                  ),
                ),
              if (!order.isPreview && order.status == OrderStatus.placed)
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await provider.cancelOrder(reference);
                    } on StateError catch (e) {
                      if (context.mounted) showMessage(context, e.message);
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel order'),
                ),
              SectionHeading('Your handover'),
              JourneyCard(journey: order.journey, editable: false),
              SizedBox(height: 14),
              Notice(order.journey.pickup.instructions),
              SizedBox(height: 12),
              if (order.status != OrderStatus.cancelled)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.password_rounded,
                      color: AppTheme.colors(context).accent,
                    ),
                    title: Text(
                      '${order.isPreview ? 'Mock verification code' : 'Handover code'}: ${order.verificationCode}',
                    ),
                    subtitle: Text(
                      order.isPreview
                          ? 'Illustrative only · show at simulated handover'
                          : 'Share only when your order arrives. Pay ${money(order.totalPaise)} in cash.',
                    ),
                  ),
                ),
              SectionHeading(order.vendorName),
              for (final item in order.items)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item.quantity} × ${item.product.name}'),
                      ),
                      Text(money(item.subtotalPaise)),
                    ],
                  ),
                ),
              SizedBox(height: 16),
              PriceSummary(
                subtotal: order.subtotalPaise,
                delivery: order.deliveryFeePaise,
                platform: order.platformFeePaise,
              ),
              SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text('Back to your journey'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
