import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/demo_format.dart';
import '../../core/utils/partner_navigation.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/roo_tip.dart';
import '../../widgets/status_badge.dart';
import '../requests/request_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final entries = repo.history.where(
      (e) =>
          _filter == 'All' ||
          (_filter == 'Completed' &&
              e.order.status == DeliveryStatus.delivered) ||
          (_filter == 'Rejected' &&
              e.order.status == DeliveryStatus.rejected) ||
          (_filter == 'Cancelled' &&
              e.order.status == DeliveryStatus.cancelled),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery history')),
      body: SafeArea(
        child: AppPage(
          storageId: 'history',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Every stop\nhas a story.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Demo records · Simulated timestamps',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in [
                    'All',
                    'Completed',
                    'Rejected',
                    'Cancelled',
                  ])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (entries.isEmpty)
                const RooTip(
                  title: 'Nothing in this chapter yet',
                  message: 'Completed, rejected and cancelled demo requests will appear here.',
                ),
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.order.id,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            StatusBadge(status: entry.order.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${entry.order.pickup.name} → ${entry.order.handover.name}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${DemoFormat.date(entry.occurredAt)} · Demo time',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          entry.order.status == DeliveryStatus.delivered
                              ? '${DemoFormat.money(entry.order.rewardPaise)} demo reward'
                              : 'No reward recorded',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color:
                                    entry.order.status ==
                                        DeliveryStatus.delivered
                                    ? AppColors.lime
                                    : AppColors.textSecondary,
                              ),
                        ),
                        TextButton(
                          onPressed: () => PartnerNavigation.open(
                            context,
                            RequestDetailsScreen(orderId: entry.order.id),
                          ),
                          child: const Text('View record'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
