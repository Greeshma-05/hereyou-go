import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/demo_format.dart';
import '../models/delivery_status.dart';
import '../services/partner_repository.dart';

class EarningsChart extends StatelessWidget {
  const EarningsChart({required this.repository, super.key});
  final PartnerRepository repository;
  @override
  Widget build(BuildContext context) {
    final now = repository.demoNow;
    final days = List.generate(
      7,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i)),
    );
    final amounts = days
        .map(
          (day) => repository.history
              .where(
                (e) =>
                    e.order.status == DeliveryStatus.delivered &&
                    e.occurredAt.year == day.year &&
                    e.occurredAt.month == day.month &&
                    e.occurredAt.day == day.day,
              )
              .fold<int>(0, (sum, e) => sum + e.order.rewardPaise),
        )
        .toList();
    final maximum = amounts.fold<int>(1, math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Semantics(
              label:
                  '${days[i].day}/${days[i].month}: ${DemoFormat.money(amounts[i])} demo earnings',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 100,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: math.max(6, amounts[i] / maximum * 100),
                            decoration: BoxDecoration(
                              color: amounts[i] > 0
                                  ? AppColors.lime
                                  : AppColors.outline,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${days[i].day}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
