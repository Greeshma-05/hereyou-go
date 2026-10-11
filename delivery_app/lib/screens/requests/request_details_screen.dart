import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/demo_action.dart';
import '../../core/utils/demo_format.dart';
import '../../core/utils/partner_navigation.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/route_info_row.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/stop_fit_badge.dart';
import '../mission/active_mission_screen.dart';

class RequestDetailsScreen extends StatelessWidget {
  const RequestDetailsScreen({required this.orderId, super.key});
  final String orderId;
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final order = repo.order(orderId);
    final fit = repo.fit(order);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(orderId)),
      body: SafeArea(
        child: AppPage(
          storageId: 'details-$orderId',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A LITTLE DETOUR.\nA BIG DIFFERENCE.',
                style: text.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                order.routeContext,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(status: order.status),
                  StopFitBadge(result: fit),
                ],
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(order.traveler, style: text.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      order.category,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${item.quantity} × ${item.name}',
                          style: text.bodyLarge,
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Divider(),
                    RouteInfoRow(
                      icon: Icons.storefront_outlined,
                      label: 'Pickup point',
                      value: order.pickup.name,
                      detail: order.pickup.detail,
                    ),
                    RouteInfoRow(
                      icon: Icons.train_outlined,
                      label: 'Handover point',
                      value: order.handover.name,
                      detail: order.handover.detail,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your StopFit breakdown', style: text.titleLarge),
                    const SizedBox(height: 12),
                    Text(fit.explanation),
                    const SizedBox(height: 16),
                    Text(
                      'To pickup: ${order.pickupKm} km\nExtra detour: ${order.detourKm} km\nExpected wait: ${order.waitMinutes} min\nAvailable window: ${order.availableMinutes} min\nEstimated effort: ${fit.estimatedMinutes} min\nTime margin: ${fit.marginMinutes} min',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Demo rule: 20 km/h for pickup + detour, plus waiting and 5 minutes handling. This is not live routing or a guaranteed handover time.',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                DemoFormat.money(order.rewardPaise),
                style: text.displaySmall?.copyWith(color: AppColors.lime),
              ),
              Text(
                'Simulated delivery reward · No real payment',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              if (order.status == DeliveryStatus.pending) ...[
                if (!repo.partner.isOnline) ...[
                  Text(
                    'You are offline. Go online to accept requests.',
                    style: text.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => repo.setOnline(true),
                    child: const Text('Go online'),
                  ),
                ],
                if (repo.activeMission != null)
                  const Text(
                    'Finish your current mission before accepting another.',
                  ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Accept request',
                  icon: Icons.check_rounded,
                  onPressed: repo.partner.isOnline && repo.activeMission == null
                      ? () => runDemoAction(context, () => repo.accept(orderId))
                      : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      runDemoAction(context, () => repo.reject(orderId)),
                  child: const Text('Reject request'),
                ),
              ] else if (order.status.isActive)
                AppButton(
                  label: 'Open active mission',
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
                )
              else
                Text(
                  order.status == DeliveryStatus.delivered
                      ? 'This delivery is complete. Its reward appears in Earnings.'
                      : 'This request is closed and can no longer be accepted.',
                  style: text.bodyMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
