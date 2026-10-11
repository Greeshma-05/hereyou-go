import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/partner_navigation.dart';
import '../../data/demo_data.dart';
import '../../models/delivery_request.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_page.dart';
import '../../widgets/request_card.dart';
import '../../widgets/roo_tip.dart';
import '../../widgets/route_map.dart';
import '../requests/request_details_screen.dart';

class RoutePulseScreen extends StatefulWidget {
  const RoutePulseScreen({super.key});
  @override
  State<RoutePulseScreen> createState() => _RoutePulseScreenState();
}

class _RoutePulseScreenState extends State<RoutePulseScreen> {
  String? _selectedId;
  void _select(BuildContext context, DeliveryRequest order) {
    setState(() => _selectedId = order.id);
    final repo = SessionScope.repositoryOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: RequestCard(
              order: repo.order(order.id),
              fit: repo.fit(order),
              onOpen: () {
                Navigator.pop(sheetContext);
                PartnerNavigation.open(
                  context,
                  RequestDetailsScreen(orderId: order.id),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final orders = repo.requests
        .where((o) => o.status == DeliveryStatus.pending || o.status.isActive)
        .toList();
    final selected =
        orders.where((o) => o.id == _selectedId).firstOrNull ??
        orders.firstOrNull;
    return AppPage(
      storageId: 'route-pulse',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'READ THE ROUTE',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.lime),
          ),
          const SizedBox(height: 10),
          Text('RoutePulse', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            'Your journey. A few meaningful stops.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          RouteMap(
            orders: orders,
            selectedId: selected?.id,
            onSelected: (order) => _select(context, order),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stop in DemoData.stops) Chip(label: Text(stop.name)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final order in orders)
                ActionChip(
                  label: Text(order.id),
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  onPressed: () => _select(context, order),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (selected != null)
            RequestCard(
              order: selected,
              fit: repo.fit(selected),
              onOpen: () => PartnerNavigation.open(
                context,
                RequestDetailsScreen(orderId: selected.id),
              ),
            )
          else
            const RooTip(
              title: 'The route is yours',
              message: 'All demo opportunities have been reviewed. Your completed and rejected requests remain in History.',
            ),
        ],
      ),
    );
  }
}
