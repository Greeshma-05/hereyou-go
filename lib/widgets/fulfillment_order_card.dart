import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/formatters.dart';
import '../core/utils/navigation.dart';
import '../data/fulfillment_repository.dart';
import 'common.dart';

String fulfillmentStatus(String status) => switch (status) {
  'placed' => 'New order',
  'confirmed' => 'Accepted',
  'preparing' => 'Preparing',
  'ready' => 'Ready for pickup',
  'pickedUp' => 'On the way',
  'handedOver' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status,
};

class FulfillmentOrderCard extends StatefulWidget {
  const FulfillmentOrderCard({
    super.key,
    required this.order,
    required this.repository,
    this.vendor = false,
    this.onAssignCourier,
  });
  final Map<String, dynamic> order;
  final FulfillmentRepository repository;
  final bool vendor;
  final VoidCallback? onAssignCourier;
  @override
  State<FulfillmentOrderCard> createState() => _FulfillmentOrderCardState();
}

class _FulfillmentOrderCardState extends State<FulfillmentOrderCard> {
  bool busy = false;
  Future<void> _act(String status) async {
    String? code;
    if (status == 'handedOver') {
      final controller = TextEditingController();
      code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm handover'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Collect ${money(widget.order['totalPaise'] as int)} in cash and ask the customer for their handover code.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Customer’s four-digit code',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Verify & finish'),
            ),
          ],
        ),
      );
      // Dialog route finishes animating before its TextField is disposed.
      Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
      if (code == null || !mounted) return;
    }
    if (status == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text(
            'The customer will be notified in their order screen and reserved stock will be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.transition(
        widget.order['reference'] as String,
        status,
        code: code,
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is StateError
              ? e.message
              : 'Could not update the order. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _navigate(Map target) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${target['latitude']},${target['longitude']}',
      'travelmode': 'driving',
    });
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      showMessage(
        context,
        'Could not open navigation. Use the address shown on this order.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order, status = o['status'] as String;
    final pickup = o['pickup'] as Map,
        delivery = (o['journey'] as Map)['pickup'] as Map;
    final terminal = ['handedOver', 'cancelled'].contains(status);
    final next = widget.vendor
        ? {
            'placed': 'confirmed',
            'confirmed': 'preparing',
            'preparing': 'ready',
          }[status]
        : {'ready': 'pickedUp', 'pickedUp': 'handedOver'}[status];
    final action = {
      'confirmed': 'Accept order',
      'preparing': 'Start preparing',
      'ready': 'Mark ready for pickup',
      'pickedUp': 'Confirm pickup',
      'handedOver': 'Verify handover',
    }[next];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(text: fulfillmentStatus(status).toUpperCase()),
                StatusBadge(
                  text: o['courierName'] == null
                      ? 'AWAITING PARTNER'
                      : 'PARTNER ASSIGNED',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.vendor
                  ? 'Delivery to ${delivery['name']}'
                  : o['vendorName'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              o['reference'] as String,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text('Pickup: ${pickup['address']}'),
            Text('Deliver to: ${delivery['name']}'),
            Text(delivery['instructions'] as String),
            if (o['courierName'] != null) Text('Partner: ${o['courierName']}'),
            const Divider(height: 28),
            for (final line in o['items'] as List)
              Text('${line['quantity']} × ${line['product']['name']}'),
            const SizedBox(height: 12),
            Text(
              'Cash to collect: ${money(o['totalPaise'] as int)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!widget.vendor)
              Text('Delivery fee: ${money(o['deliveryFeePaise'] as int)}'),
            if (!terminal) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!widget.vendor)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _navigate(status == 'pickedUp' ? delivery : pickup),
                      icon: const Icon(Icons.navigation_outlined),
                      label: Text(
                        status == 'pickedUp'
                            ? 'Navigate to customer'
                            : 'Navigate to shop',
                      ),
                    ),
                  if (next != null)
                    FilledButton(
                      onPressed: busy ? null : () => _act(next),
                      child: Text(busy ? 'Updating…' : action!),
                    ),
                  if (widget.vendor &&
                      o['courierId'] == null &&
                      ['confirmed', 'preparing', 'ready'].contains(status) &&
                      widget.onAssignCourier != null)
                    OutlinedButton.icon(
                      onPressed: busy ? null : widget.onAssignCourier,
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Assign delivery partner'),
                    ),
                  if (widget.vendor && status != 'pickedUp')
                    TextButton(
                      onPressed: busy ? null : () => _act('cancelled'),
                      child: const Text('Cancel order'),
                    ),
                ],
              ),
              if (!widget.vendor && next == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'The shop is preparing this order. Pickup becomes available when it is marked ready.',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
