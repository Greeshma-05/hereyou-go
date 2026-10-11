import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/demo_format.dart';
import '../models/delivery_request.dart';
import '../models/stop_fit_result.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'route_info_row.dart';
import 'status_badge.dart';
import 'stop_fit_badge.dart';

class RequestCard extends StatelessWidget {
  const RequestCard({
    required this.order,
    required this.fit,
    required this.onOpen,
    super.key,
  });
  final DeliveryRequest order;
  final StopFitResult fit;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(
              order.id,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            Text(
              DemoFormat.money(order.rewardPaise),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: AppColors.lime),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(order.traveler, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          order.itemSummary,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        RouteInfoRow(
          icon: Icons.storefront_outlined,
          label: 'Pickup',
          value: order.pickup.name,
        ),
        RouteInfoRow(
          icon: Icons.trip_origin_rounded,
          label: 'Handover',
          value: order.handover.name,
        ),
        const SizedBox(height: 10),
        Text(
          '${order.pickupKm} km to pickup · +${order.detourKm} km detour\n~${fit.estimatedMinutes} min · Demo estimates',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StopFitBadge(result: fit),
            StatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'View mission',
          icon: Icons.arrow_forward_rounded,
          onPressed: onOpen,
        ),
      ],
    ),
  );
}
