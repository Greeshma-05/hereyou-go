import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/delivery_status.dart';

class MissionProgress extends StatelessWidget {
  const MissionProgress({required this.status, super.key});
  final DeliveryStatus status;
  static const stages = [
    DeliveryStatus.accepted,
    DeliveryStatus.travelingToPickup,
    DeliveryStatus.arrivedAtVendor,
    DeliveryStatus.pickedUp,
    DeliveryStatus.inTransit,
    DeliveryStatus.readyForHandover,
    DeliveryStatus.handoverConfirmed,
    DeliveryStatus.delivered,
  ];
  @override
  Widget build(BuildContext context) {
    final current = stages.indexOf(status);
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? AppColors.lime
                        : AppColors.neutralTint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: i < current
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.background,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: i == current
                                  ? AppColors.background
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    stages[i].label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: i == current
                          ? AppColors.lime
                          : i < current
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
