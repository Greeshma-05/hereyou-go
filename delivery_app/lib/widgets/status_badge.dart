import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/delivery_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (status) {
      DeliveryStatus.pending => (
        'Pending',
        Icons.schedule_rounded,
        AppColors.warningText,
        AppColors.warningTint,
      ),
      DeliveryStatus.accepted ||
      DeliveryStatus.travelingToPickup ||
      DeliveryStatus.arrivedAtVendor => (
        status.label,
        Icons.check_circle_outline_rounded,
        AppColors.lime,
        AppColors.mintTint,
      ),
      DeliveryStatus.pickedUp => (
        'Picked up',
        Icons.inventory_2_outlined,
        AppColors.lime,
        AppColors.mintTint,
      ),
      DeliveryStatus.inTransit ||
      DeliveryStatus.readyForHandover ||
      DeliveryStatus.handoverConfirmed => (
        status.label,
        Icons.local_shipping_outlined,
        AppColors.lime,
        AppColors.mintTint,
      ),
      DeliveryStatus.delivered => (
        'Delivered',
        Icons.task_alt_rounded,
        AppColors.lime,
        AppColors.mintTint,
      ),
      DeliveryStatus.cancelled || DeliveryStatus.rejected => (
        status.label,
        Icons.cancel_outlined,
        AppColors.textSecondary,
        AppColors.neutralTint,
      ),
      DeliveryStatus.failed => (
        'Failed',
        Icons.error_outline_rounded,
        AppColors.error,
        AppColors.errorTint,
      ),
    };

    return Semantics(
      label: 'Delivery status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
