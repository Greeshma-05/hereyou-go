import 'package:flutter/material.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/widgets/common.dart';
import 'package:route_rescue/widgets/fulfillment_order_card.dart';
import '../state/order_errors.dart';
import 'nearby_partners_screen.dart';

bool _finished(Map<String, dynamic> order) =>
    ['handedOver', 'cancelled'].contains(order['status']);

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({
    super.key,
    required this.repository,
    required this.uid,
  });
  final FulfillmentRepository repository;
  final String uid;
  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  late Stream<List<Map<String, dynamic>>> stream;
  String filter = 'Active';
  @override
  void initState() {
    super.initState();
    connect();
  }

  void connect() =>
      stream = widget.repository.ordersFor('vendorId', widget.uid);

  @override
  void didUpdateWidget(covariant VendorOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.repository != widget.repository) {
      connect();
    }
  }

  Future<void> choosePartner(Map<String, dynamic> order) async {
    final assigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NearbyPartnersScreen(repository: widget.repository, order: order),
      ),
    );
    if (assigned == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Partner assigned. The delivery app will receive this order.',
          ),
        ),
      );
    }
  }

  bool matches(Map<String, dynamic> order, String group) => switch (group) {
    'New' => order['status'] == 'placed',
    'Needs partner' =>
      ['confirmed', 'preparing', 'ready'].contains(order['status']) &&
          order['courierId'] == null,
    'History' => _finished(order),
    _ => !_finished(order),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Customer orders'),
      actions: [
        IconButton(
          tooltip: 'Refresh orders',
          onPressed: () => setState(connect),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Notice(orderError(snapshot.error!), warning: true),
                  TextButton.icon(
                    onPressed: () => setState(connect),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry orders'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const LoadingView(message: 'Connecting customer orders…');
          }
          final orders = snapshot.data!;
          final visible = orders.where((o) => matches(o, filter));
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Notice(
                  'Accept incoming orders, assign an available partner within 5 km, then prepare and mark ready for pickup. New orders and delivery progress update automatically while the app is open.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final group in [
                      'Active',
                      'New',
                      'Needs partner',
                      'History',
                    ])
                      ChoiceChip(
                        label: Text(
                          '$group (${orders.where((o) => matches(o, group)).length})',
                        ),
                        selected: filter == group,
                        labelStyle: TextStyle(
                          color: filter == group
                              ? AppTheme.colors(context).onAccent
                              : AppTheme.colors(context).ink,
                        ),
                        onSelected: (_) => setState(() => filter = group),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: orders.isEmpty
                        ? 'Ready for your first order'
                        : 'No orders in this view',
                    message: orders.isEmpty
                        ? 'Confirmed customer checkouts from your shop appear here automatically. Guest previews are not sent to the shop.'
                        : 'Choose another filter or wait for the next update.',
                  ),
                for (final order in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FulfillmentOrderCard(
                      key: ValueKey(order['reference']),
                      order: order,
                      repository: widget.repository,
                      vendor: true,
                      onAssignCourier: () => choosePartner(order),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// A stable dashboard subscription keeps incoming orders visible outside the inbox.
class VendorOrdersButton extends StatefulWidget {
  const VendorOrdersButton({
    super.key,
    required this.repository,
    required this.uid,
  });
  final FulfillmentRepository repository;
  final String uid;
  @override
  State<VendorOrdersButton> createState() => _VendorOrdersButtonState();
}

class _VendorOrdersButtonState extends State<VendorOrdersButton> {
  late Stream<List<Map<String, dynamic>>> stream;
  @override
  void initState() {
    super.initState();
    stream = widget.repository.ordersFor('vendorId', widget.uid);
  }

  @override
  void didUpdateWidget(covariant VendorOrdersButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.repository != widget.repository) {
      stream = widget.repository.ordersFor('vendorId', widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final count =
              snapshot.data?.where((o) => o['status'] == 'placed').length ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VendorOrdersScreen(
                      repository: widget.repository,
                      uid: widget.uid,
                    ),
                  ),
                ),
                icon: Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                label: const Text('Customer orders'),
              ),
              if (count > 0)
                Text(
                  '$count new ${count == 1 ? 'order' : 'orders'} to accept',
                  textAlign: TextAlign.center,
                ),
              if (snapshot.hasError)
                const Text(
                  'Order updates paused. Open Customer orders to retry.',
                  textAlign: TextAlign.center,
                ),
            ],
          );
        },
      );
}
