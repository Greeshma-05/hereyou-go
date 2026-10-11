import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/demo_format.dart';
import '../../core/utils/partner_navigation.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/earnings_chart.dart';
import '../../widgets/roo_tip.dart';
import '../../widgets/section_heading.dart';
import '../../widgets/stat_card.dart';
import '../history/history_screen.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final rewards = repo.history
        .where((e) => e.order.status == DeliveryStatus.delivered)
        .toList();
    final total = rewards.fold<int>(0, (sum, e) => sum + e.order.rewardPaise);
    final average = rewards.isEmpty ? 0 : (total / rewards.length).round();
    final text = Theme.of(context).textTheme;
    return AppPage(
      storageId: 'earnings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR EFFORT, RECOGNISED',
            style: text.labelSmall?.copyWith(color: AppColors.lime),
          ),
          const SizedBox(height: 12),
          Text('Little journeys.\nReal purpose.', style: text.headlineLarge),
          const SizedBox(height: 24),
          AppCard(
            color: AppColors.mintTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY’S DEMO EARNINGS',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  DemoFormat.money(repo.todayEarningsPaise),
                  style: text.displaySmall?.copyWith(
                    fontSize: 48,
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Demo day: ${repo.demoNow.day}/${repo.demoNow.month}/${repo.demoNow.year}\nSimulated rewards · No real payouts',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: (bounds.maxWidth - 12) / 2,
                  child: StatCard(
                    value: '${repo.completedCount}',
                    label: 'Completed deliveries',
                    icon: Icons.task_alt_rounded,
                  ),
                ),
                SizedBox(
                  width: (bounds.maxWidth - 12) / 2,
                  child: StatCard(
                    value: DemoFormat.money(average),
                    label: 'Average demo reward',
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DemoFormat.money(repo.weeklyEarningsPaise),
                  style: text.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Last 7 demo days',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                EarningsChart(repository: repo),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionHeading(
            title: 'Recent rewards',
            trailing: IconButton(
              tooltip: 'Delivery history',
              onPressed: () =>
                  PartnerNavigation.open(context, const HistoryScreen()),
              icon: const Icon(Icons.history_rounded, color: AppColors.lime),
            ),
          ),
          const SizedBox(height: 16),
          if (rewards.isEmpty)
            const RooTip(
              title: 'Your first reward is ahead',
              message: 'Complete a delivery after SafePass verification to see its demo reward here.',
            ),
          for (final entry in rewards.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(entry.order.id, style: text.titleMedium),
                        Text(
                          '+ ${DemoFormat.money(entry.order.rewardPaise)}',
                          style: text.titleLarge?.copyWith(
                            color: AppColors.lime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${entry.order.handover.name} · ${DemoFormat.date(entry.occurredAt)}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () =>
                PartnerNavigation.open(context, const HistoryScreen()),
            icon: const Icon(Icons.history_rounded),
            label: const Text('View delivery history'),
          ),
        ],
      ),
    );
  }
}
