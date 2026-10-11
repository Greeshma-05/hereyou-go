import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/demo_format.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/circle_action.dart';
import '../../widgets/roo_tip.dart';
import '../../widgets/route_canvas.dart';
import '../../widgets/section_heading.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/stop_fit_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.onOpenRequests,
    this.onOpenMap,
    this.onOpenProfile,
    this.onOpenMission,
    this.onOpenNotifications,
    this.onOpenOrder,
    super.key,
  });
  final VoidCallback onOpenRequests;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenMission;
  final VoidCallback? onOpenNotifications;
  final ValueChanged<String>? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final theme = Theme.of(context).textTheme;
    final available = repo.requests
        .where((o) => o.status == DeliveryStatus.pending)
        .length;
    final mission = repo.activeMission;
    final recommendation = repo.recommended;
    return AppPage(
      storageId: 'dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAction(
                icon: Icons.person_outline_rounded,
                label: 'Open profile',
                onPressed: onOpenProfile ?? onOpenRequests,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME ABOARD',
                      style: theme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(repo.partner.name, style: theme.titleMedium),
                  ],
                ),
              ),
              CircleAction(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                count: repo.unreadCount,
                onPressed:
                    onOpenNotifications ??
                    () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: repo.notifications
                              .map(
                                (n) => ListTile(
                                  title: Text(n.title),
                                  subtitle: Text(n.message),
                                  onTap: () {
                                    repo.markRead(n.id);
                                    Navigator.pop(context);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: repo.partner.isOnline
                      ? AppColors.lime
                      : AppColors.textSecondary,
                  shape: BoxShape.circle,
                  boxShadow: repo.partner.isOnline
                      ? [
                          BoxShadow(
                            color: AppColors.lime.withValues(alpha: .3),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  repo.partner.isOnline
                      ? 'ONLINE · READY FOR REQUESTS'
                      : 'OFFLINE · ON YOUR TERMS',
                  style: theme.labelSmall?.copyWith(
                    color: repo.partner.isOnline
                        ? AppColors.lime
                        : AppColors.textSecondary,
                    letterSpacing: .8,
                  ),
                ),
              ),
              Semantics(
                label: 'Availability',
                child: Switch(
                  value: repo.partner.isOnline,
                  onChanged: repo.setOnline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            mission != null
                ? 'A journey is\ncounting on you.'
                : 'Ready for your',
            style: theme.displaySmall?.copyWith(
              fontSize: 39,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (mission == null)
            Text(
              'NEXT MISSION?',
              style: theme.displaySmall?.copyWith(
                color: AppColors.lime,
                fontStyle: FontStyle.italic,
                fontSize: 39,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            mission != null
                ? '${mission.id} · ${mission.status.label}. Your next step is ready.'
                : repo.partner.isOnline
                ? '$available opportunities along your journey. Make a little detour. Make a big difference.'
                : 'Take a breath. Go online when you are ready to bring essentials to someone’s journey.',
            style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RouteCanvas(height: 210),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR DEMO CORRIDOR',
                        style: theme.labelSmall?.copyWith(
                          color: AppColors.lime,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Bengaluru → Mysuru', style: theme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '$available requests · 6 stops · Simulated route',
                        style: theme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        value: .22,
                        minHeight: 3,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '22% journey preview · Demo position near Kengeri',
                        style: theme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Open RoutePulse',
                        icon: Icons.near_me_outlined,
                        onPressed: onOpenMap ?? onOpenRequests,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeading(
            title: 'Your shift, at a glance',
            subtitle: 'Local demo activity',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in [
                  (
                    value: '$available',
                    label: 'Available requests',
                    icon: Icons.inbox_outlined,
                  ),
                  (
                    value: mission == null ? '0' : '1',
                    label: 'Active deliveries',
                    icon: Icons.route_rounded,
                  ),
                  (
                    value: '${repo.completedCount}',
                    label: 'Completed deliveries',
                    icon: Icons.task_alt_rounded,
                  ),
                  (
                    value: DemoFormat.money(repo.todayEarningsPaise),
                    label: 'Today’s demo earnings',
                    icon: Icons.wallet_outlined,
                  ),
                ])
                  SizedBox(
                    width: (bounds.maxWidth - 12) / 2,
                    child: StatCard(
                      value: stat.value,
                      label: stat.label,
                      icon: stat.icon,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (mission != null)
            AppButton(
              label: 'Continue active mission',
              icon: Icons.arrow_forward_rounded,
              onPressed: onOpenMission ?? onOpenRequests,
            )
          else if (recommendation != null) ...[
            const SectionHeading(
              title: 'Made for your route',
              subtitle: 'Recommended by StopFit · Demo estimates',
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StopFitBadge(result: repo.fit(recommendation)),
                  const SizedBox(height: 18),
                  Text(recommendation.pickup.name, style: theme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'To ${recommendation.handover.name}',
                    style: theme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text(
                        DemoFormat.money(recommendation.rewardPaise),
                        style: theme.headlineSmall?.copyWith(
                          color: AppColors.lime,
                        ),
                      ),
                      Text(
                        '+${recommendation.detourKm} km · ~${repo.fit(recommendation).estimatedMinutes} min',
                        style: theme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'View mission',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => onOpenOrder != null
                        ? onOpenOrder!(recommendation.id)
                        : onOpenRequests(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          RooTip(
            message: repo.partner.isOnline
                ? 'Small stops. Big relief. Check StopFit and your handover point before accepting.'
                : 'You’re offline. Browse freely, then go online to accept your first mission.',
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Explore requests',
            icon: Icons.explore_outlined,
            onPressed: onOpenRequests,
          ),
        ],
      ),
    );
  }
}
