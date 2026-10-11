import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/partner_navigation.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page.dart';
import '../../widgets/request_card.dart';
import '../../widgets/roo_tip.dart';
import '../mission/active_mission_screen.dart';
import 'request_details_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _search = TextEditingController();
  String _filter = 'New';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final query = _search.text.trim().toLowerCase();
    final orders = repo.requests.where((o) {
      final matches =
          '${o.id} ${o.traveler} ${o.pickup.name} ${o.handover.name} ${o.category} ${o.itemSummary}'
              .toLowerCase()
              .contains(query);
      return matches &&
          (_filter == 'All' ||
              (_filter == 'New' && o.status == DeliveryStatus.pending) ||
              (_filter == 'Accepted' && o.status.isActive));
    }).toList();
    return AppPage(
      storageId: 'requests',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ALONG YOUR JOURNEY',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.lime),
          ),
          const SizedBox(height: 10),
          Text('Deliveries', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            repo.partner.isOnline
                ? 'Find your next small stop with a big purpose.'
                : 'Offline · Browse requests, then go online to accept.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (repo.activeMission != null) ...[
            AppButton(
              label: 'Continue active mission',
              icon: Icons.route_rounded,
              onPressed: () => PartnerNavigation.open(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text('Active delivery')),
                  body: SafeArea(
                    child: ActiveMissionScreen(
                      onOpenRequests: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search requests',
              hintText: 'Order, traveler or stop',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in ['All', 'New', 'Accepted'])
                ChoiceChip(
                  label: Text(filter),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (orders.isEmpty)
            const RooTip(
              title: 'A little breathing room',
              message: 'No requests match this view. Try another filter or a different search.',
            ),
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RequestCard(
                order: order,
                fit: repo.fit(order),
                onOpen: () => PartnerNavigation.open(
                  context,
                  RequestDetailsScreen(orderId: order.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
