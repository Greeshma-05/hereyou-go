import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../providers/catalog_provider.dart';
import '../../data/courier_tracking_source.dart';
import '../../models/order_model.dart';
import '../../providers/delivery_map_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/delivery_routing_service.dart';
import '../../widgets/common.dart';
import 'delivery_route_map.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({
    super.key,
    required this.reference,
    this.routingService,
    this.trackingSource,
  });
  final String reference;
  final DeliveryRoutingService? routingService;
  final CourierTrackingSource? trackingSource;
  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  late final DeliveryMapProvider _map;
  bool _routeAllowed = false;
  @override
  void initState() {
    super.initState();
    final order = context.read<OrderProvider>().byReference(widget.reference);
    _map = DeliveryMapProvider(
      reference: order.reference,
      shop:
          order.pickupPosition ??
          CatalogProvider.of(
            context,
            listen: false,
          ).vendor(order.vendorId)?.position,
      delivery: order.journey.pickup.position,
      routing: widget.routingService,
      tracking:
          widget.trackingSource ??
          (order.isPreview ? null : context.read<OrderProvider>().tracking),
    );
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    if (!_routeAllowed) {
      final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Calculate the road route?'),
          content: SingleChildScrollView(
            child: Text(
              'The shop and delivery pin coordinates will be sent to ${_map.routingHost} to calculate a driving route. '
              'Your name, order contents and device location are not sent.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep pins only'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Calculate route'),
            ),
          ],
        ),
      );
      if (!mounted || allowed != true) return;
      _routeAllowed = true;
    }
    await _map.loadRoute();
  }

  Future<void> _openLink(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Keep the map usable without a browser. */
    }
    if (mounted) {
      showMessage(context, 'Could not open the link. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final order = orders.orders
        .where((o) => o.reference == widget.reference)
        .firstOrNull;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery map')),
        body: const Center(child: Text('This order is no longer available.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery map')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _map,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              // Large reading settings use a normal scrollable page so nothing is trapped in a small sheet.
              final accessibleLayout =
                  MediaQuery.textScalerOf(context).scale(14) > 20 ||
                  constraints.maxHeight < 550;
              Widget map(double bottomInset) => DeliveryRouteMap(
                shop: _map.shop,
                destination: _map.delivery,
                shopName: order.vendorName,
                destinationName: order.journey.pickup.name,
                route: _map.roadRoute,
                courier: _map.courier,
                courierLive: _map.courierLive,
                bottomInset: bottomInset,
              );
              if (accessibleLayout) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 360, child: map(0)),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: _details(context, order),
                      ),
                    ],
                  ),
                );
              }
              return Stack(
                children: [
                  Positioned.fill(child: map(constraints.maxHeight * .43)),
                  DraggableScrollableSheet(
                    initialChildSize: .43,
                    minChildSize: .25,
                    maxChildSize: .9,
                    snap: true,
                    snapSizes: const [.43, .9],
                    builder: (context, controller) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.colors(context).canvas,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        border: Border.all(
                          color: AppTheme.colors(context).border,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 20),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.colors(context).muted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _details(context, order),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _details(BuildContext context, RescueOrder order) {
    final colors = AppTheme.colors(context);
    final route = _map.roadRoute;
    final fix = _map.courier;
    final complete = order.status == OrderStatus.handedOver;
    final courierTitle = complete
        ? 'Delivery completed'
        : order.status == OrderStatus.cancelled
        ? 'Delivery cancelled'
        : !_map.tracking.connected
        ? 'Courier tracking not connected'
        : _map.courierLive
        ? 'Receiving courier location'
        : fix != null
        ? 'Courier location is out of date'
        : _map.trackingError
        ? 'Courier connection interrupted'
        : 'Waiting for courier location';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBadge(
          text: order.isPreview ? 'DELIVERY PREVIEW' : 'LIVE DELIVERY',
        ),
        const SizedBox(height: 12),
        Text(
          order.status.label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (route != null) ...[
          const SizedBox(height: 8),
          Text(
            'Drive estimate · ${(route.distanceMeters / 1000).toStringAsFixed(1)} km · ${route.drivingMinutes} min',
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 12),
        Semantics(
          label: order.isPreview
              ? 'Preview progress: ${order.status.label}'
              : 'Delivery progress: ${order.status.label}',
          child: Row(
            children: [
              for (final status
                  in (order.isPreview
                          ? OrderStatus.previewStages
                          : OrderStatus.progressStages)
                      .where(
                        (s) => order.isPreview || s != OrderStatus.assigned,
                      ))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: status.index <= order.status.index
                            ? colors.accent
                            : colors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colors.surface,
              foregroundColor: colors.accent,
              child: Icon(
                _map.courierLive
                    ? Icons.delivery_dining
                    : Icons.person_search_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courierTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    fix == null
                        ? 'Live movement and arrival time will appear when a delivery partner connects.'
                        : '${fix.name ?? 'Delivery partner'} · Last update ${TimeOfDay.fromDateTime(fix.recordedAt.toLocal()).format(context)}'
                              '${fix.accuracyMeters == null ? '' : ' · ±${fix.accuracyMeters!.round()} m'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _stop(
          context,
          Icons.storefront_outlined,
          'FROM THE SHOP',
          order.vendorName,
          _map.shop == null ? 'Shop coordinates unavailable' : 'Shop location',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 19),
          child: Container(width: 2, height: 22, color: colors.border),
        ),
        _stop(
          context,
          Icons.flag_outlined,
          'DELIVER TO',
          order.journey.pickup.name,
          order.journey.pickup.instructions,
        ),
        const SizedBox(height: 22),
        if (route != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.tint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(route.distanceMeters / 1000).toStringAsFixed(1)} km · about ${route.drivingMinutes} min',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text('Estimated drive from shop to delivery pin'),
                const SizedBox(height: 6),
                Text(
                  'Excludes preparation, traffic and stops. Dotted lines connect pins to the nearest road.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Calculated ${TimeOfDay.fromDateTime(route.fetchedAt.toLocal()).format(context)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_map.error != null) ...[
          Notice(_map.error!, warning: true),
          const SizedBox(height: 12),
        ],
        if (_map.shop != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _map.loading ? null : _loadRoute,
              icon: _map.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route_outlined),
              label: Text(
                _map.loading
                    ? 'Finding a road route…'
                    : _map.error != null
                    ? 'Retry road route'
                    : route == null
                    ? 'Show road route'
                    : 'Refresh road route',
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          order.isPreview
              ? (complete
                    ? 'This order has reached the final preview stage.'
                    : 'Order progress is a preview. No delivery has been dispatched.')
              : (complete
                    ? 'Your order has been delivered.'
                    : 'Order progress updates from your shop and assigned partner.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Order & delivery details'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(order.reference),
                  const SizedBox(height: 10),
                  Text(
                    'Delivery pin: ${_map.delivery.latitude.toStringAsFixed(6)}, ${_map.delivery.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order.isPreview ? 'Preview handover code' : 'Handover code'}: ${order.verificationCode}',
                  ),
                  const SizedBox(height: 8),
                  for (final item in order.items)
                    Text('${item.quantity} × ${item.product.name}'),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () =>
                  _openLink('https://routing.openstreetmap.de/about.html'),
              child: const Text('Routing: FOSSGIS / OSRM'),
            ),
            TextButton(
              onPressed: () =>
                  _openLink('https://www.openstreetmap.org/fixthemap'),
              child: const Text('Fix the map'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stop(
    BuildContext context,
    IconData icon,
    String label,
    String title,
    String subtitle,
  ) {
    final colors = AppTheme.colors(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 5),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
