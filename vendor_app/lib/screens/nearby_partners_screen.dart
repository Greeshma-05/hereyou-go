import 'dart:async';
import 'package:flutter/material.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/widgets/common.dart';
import '../state/order_errors.dart';

class NearbyPartnersScreen extends StatefulWidget {
  const NearbyPartnersScreen({
    super.key,
    required this.repository,
    required this.order,
  });
  final FulfillmentRepository repository;
  final Map<String, dynamic> order;
  @override
  State<NearbyPartnersScreen> createState() => _NearbyPartnersScreenState();
}

class _NearbyPartnersScreenState extends State<NearbyPartnersScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> partners = [];
  bool loading = true;
  bool refreshing = false, _foreground = true;
  Timer? _refreshTimer;
  DateTime? updatedAt;
  String? assigning, error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!mounted || !_foreground) return;
    _refreshTimer = Timer(const Duration(seconds: 10), () {
      if (ModalRoute.of(context)?.isCurrent == true) {
        unawaited(load());
      } else {
        _scheduleRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      if (ModalRoute.of(context)?.isCurrent == true) unawaited(load());
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted || refreshing || assigning != null) return;
    _refreshTimer?.cancel();
    setState(() {
      refreshing = true;
    });
    try {
      final result = await widget.repository.nearbyCouriers(
        widget.order['reference'] as String,
      );
      if (mounted) {
        setState(() {
          partners = result;
          error = null;
          updatedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = orderError(e);
          partners = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          refreshing = false;
        });
        _scheduleRefresh();
      }
    }
  }

  Future<void> assign(Map<String, dynamic> partner) async {
    if (assigning != null || refreshing) return;
    _refreshTimer?.cancel();
    setState(() {
      assigning = partner['id'] as String;
      error = null;
    });
    try {
      await widget.repository.assignCourier(
        widget.order['reference'] as String,
        partner['id'] as String,
      );
      if (mounted) {
        setState(() => assigning = null);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = orderError(e);
          partners = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => assigning = null);
        _scheduleRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: assigning == null,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Nearby delivery partners'),
        actions: [
          IconButton(
            tooltip: 'Refresh nearby partners',
            onPressed: refreshing || assigning != null ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const LoadingView(message: 'Finding available partners…')
            : PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.order['reference'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Notice(
                      'Online partners within 5 km of this order’s shop pickup, nearest first. This list updates automatically every 10 seconds.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      refreshing
                          ? 'Updating partner availability…'
                          : updatedAt == null
                          ? 'Waiting for partner availability'
                          : 'Last checked ${TimeOfDay.fromDateTime(updatedAt!).format(context)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (error != null) ...[
                      Notice(error!, warning: true),
                      TextButton.icon(
                        onPressed: assigning == null && !refreshing
                            ? load
                            : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry nearby partners'),
                      ),
                    ] else if (partners.isEmpty) ...[
                      const EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'No available partners nearby',
                        message:
                            'Ask the partner to turn on precise location, go online and keep the delivery app open. Available partners appear here automatically. Partners already on a delivery are not available for another order.',
                      ),
                      OutlinedButton.icon(
                        onPressed: refreshing ? null : load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check again'),
                      ),
                    ],
                    for (final partner in partners)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const StatusBadge(text: 'ONLINE · AVAILABLE'),
                                const SizedBox(height: 12),
                                Text(
                                  partner['name'] as String,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${partner['vehicle']} · ${(partner['distanceKm'] as num).toStringAsFixed(1)} km from pickup',
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: assigning == null && !refreshing
                                      ? () => assign(partner)
                                      : null,
                                  icon: const Icon(Icons.delivery_dining),
                                  label: Text(
                                    assigning == partner['id']
                                        ? 'Assigning…'
                                        : 'Assign ${partner['name']}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Availability and distance are checked again when you assign. The order appears in the selected partner’s delivery app automatically.',
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
