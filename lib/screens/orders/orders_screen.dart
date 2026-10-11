import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../explore/explore_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.orders;
    final groups = <String, List<RescueOrder>>{
      'Active orders': orders
          .where(
            (o) =>
                !o.isPreview &&
                o.status != OrderStatus.handedOver &&
                o.status != OrderStatus.cancelled,
          )
          .toList(),
      'Previous orders': orders
          .where(
            (o) =>
                !o.isPreview &&
                (o.status == OrderStatus.handedOver ||
                    o.status == OrderStatus.cancelled),
          )
          .toList(),
      'Previews': orders.where((o) => o.isPreview).toList(),
    };
    return Scaffold(
      appBar: AppBar(title: Text('Your orders'), actions: [CartButton()]),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Notice(
                provider.cloudBacked
                    ? 'Live order progress updates automatically. Previews are labeled separately and are not sent to shops.'
                    : 'Guest orders and status updates are previews kept for this session.',
              ),
              if (provider.loading)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (provider.error != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Notice(provider.error!, warning: true),
                ),
              if (!provider.loading && orders.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Your journey starts here',
                  message:
                      'Your current and completed orders will appear here.',
                  action: FilledButton(
                    onPressed: () =>
                        openPage(context, ExploreScreen(initialMap: false)),
                    child: Text('Explore essentials'),
                  ),
                ),
              for (final group in groups.entries) ...[
                if (group.value.isNotEmpty) SectionHeading(group.key),
                for (final order in group.value)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => openPage(
                          context,
                          OrderDetailScreen(reference: order.reference),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppTheme.colors(context).accent,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      order.vendorName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                order.reference,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${dateLabel(order.createdAt)} · ${timeLabel(order.createdAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.isPreview
                                          ? 'Preview · not sent to shop'
                                          : order.status.label,
                                      style: TextStyle(
                                        color: AppTheme.colors(context).accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    money(order.totalPaise),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'View details',
                                style: TextStyle(
                                  color: AppTheme.colors(context).accent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
