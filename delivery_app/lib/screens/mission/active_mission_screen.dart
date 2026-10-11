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
import '../../widgets/mission_progress.dart';
import '../../widgets/roo_tip.dart';
import '../../widgets/route_canvas.dart';
import '../../widgets/route_info_row.dart';
import '../map/route_pulse_screen.dart';
import 'safe_pass_screen.dart';
import 'delivery_success_screen.dart';

class ActiveMissionScreen extends StatefulWidget {
  const ActiveMissionScreen({required this.onOpenRequests, super.key});
  final VoidCallback onOpenRequests;
  @override
  State<ActiveMissionScreen> createState() => _ActiveMissionScreenState();
}

class _ActiveMissionScreenState extends State<ActiveMissionScreen> {
  final Set<int> _checkedItems = {};
  String? _checkedOrder;
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final order = repo.activeMission;
    final text = Theme.of(context).textTheme;
    if (order == null) {
      return AppPage(
        storageId: 'active-mission',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Room for your\nnext mission.', style: text.headlineLarge),
            const SizedBox(height: 24),
            const RouteCanvas(),
            const SizedBox(height: 24),
            const RooTip(
              title: 'Your route is clear',
              message: 'No active delivery right now. Browse requests and let StopFit help you find a good match.',
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Explore requests',
              icon: Icons.explore_outlined,
              onPressed: widget.onOpenRequests,
            ),
          ],
        ),
      );
    }
    if (_checkedOrder != order.id) {
      _checkedItems.clear();
      _checkedOrder = order.id;
    }
    final pickupCheck = order.status == DeliveryStatus.arrivedAtVendor;
    final nextLabel = switch (order.status) {
      DeliveryStatus.accepted => 'Start mission',
      DeliveryStatus.travelingToPickup => 'Confirm arrival at vendor',
      DeliveryStatus.arrivedAtVendor => 'Confirm package collection',
      DeliveryStatus.pickedUp => 'Head to handover',
      DeliveryStatus.inTransit => 'Confirm arrival at handover',
      DeliveryStatus.readyForHandover => 'Open SafePass',
      DeliveryStatus.handoverConfirmed => 'Complete delivery',
      _ => 'Continue',
    };
    void next() {
      if (order.status == DeliveryStatus.readyForHandover) {
        PartnerNavigation.open(context, SafePassScreen(orderId: order.id));
      } else if (order.status == DeliveryStatus.handoverConfirmed) {
        if (runDemoAction(context, () => repo.complete(order.id))) {
          PartnerNavigation.open(
            context,
            DeliverySuccessScreen(
              order: repo.order(order.id),
              firstDelivery: repo.completedCount == 1,
            ),
          );
        }
      } else {
        runDemoAction(context, () => repo.advance(order.id, order.status));
      }
    }

    return AppPage(
      storageId: 'active-mission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ONE MISSION. EVERY DETAIL.',
            style: text.labelSmall?.copyWith(color: AppColors.lime),
          ),
          const SizedBox(height: 10),
          Text('Active delivery', style: text.headlineLarge),
          const SizedBox(height: 10),
          Text(
            '${order.id} · ${order.status.label}',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RouteCanvas(height: 190),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Simulated route · Demo locations',
                        style: text.labelSmall?.copyWith(color: AppColors.lime),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '~${repo.fit(order).estimatedMinutes} min · +${order.detourKm} km detour',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => PartnerNavigation.open(
                          context,
                          Scaffold(
                            appBar: AppBar(title: const Text('Your route')),
                            body: const SafeArea(child: RoutePulseScreen()),
                          ),
                        ),
                        icon: const Icon(Icons.near_me_outlined),
                        label: const Text('View RoutePulse'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your next step', style: text.titleLarge),
                const SizedBox(height: 12),
                Text(
                  order.status.label,
                  style: text.titleMedium?.copyWith(color: AppColors.lime),
                ),
                const SizedBox(height: 12),
                if (pickupCheck) ...[
                  const Text('Check every item against the package:'),
                  for (var i = 0; i < order.items.length; i++)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _checkedItems.contains(i),
                      title: Text(
                        '${order.items[i].quantity} × ${order.items[i].name}',
                      ),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _checkedItems.add(i);
                        } else {
                          _checkedItems.remove(i);
                        }
                      }),
                    ),
                ],
                AppButton(
                  label: nextLabel,
                  icon: Icons.arrow_forward_rounded,
                  onPressed:
                      pickupCheck && _checkedItems.length != order.items.length
                      ? null
                      : next,
                ),
                const SizedBox(height: 12),
                Text(
                  'Arrival is confirmed manually in this demo. No live tracking is running.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RouteInfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'Pickup',
                  value: order.pickup.name,
                  detail: order.pickup.detail,
                ),
                RouteInfoRow(
                  icon: Icons.flag_outlined,
                  label: 'Handover',
                  value: order.handover.name,
                  detail: order.handover.detail,
                ),
                RouteInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Traveler',
                  value: order.traveler,
                ),
                Text(
                  '${DemoFormat.money(order.rewardPaise)} demo reward',
                  style: text.titleLarge?.copyWith(color: AppColors.lime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(child: MissionProgress(status: order.status)),
        ],
      ),
    );
  }
}
