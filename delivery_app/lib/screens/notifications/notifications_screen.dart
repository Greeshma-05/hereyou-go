import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/demo_format.dart';
import '../../core/utils/partner_navigation.dart';
import '../../models/delivery_status.dart';
import '../../models/partner_notification.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/roo_tip.dart';
import '../mission/active_mission_screen.dart';
import '../requests/request_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: repo.unreadCount == 0 ? null : repo.markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AppPage(
          storageId: 'notifications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A little heads-up.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                '${repo.unreadCount} unread · Local demo inbox',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              if (!repo.partner.notificationsEnabled)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'New demo notifications are paused in Profile settings.',
                    style: TextStyle(color: AppColors.warningText),
                  ),
                ),
              if (repo.notifications.isEmpty)
                const RooTip(
                  title: 'All quiet for now',
                  message: 'Useful updates about your actual demo actions will appear here.',
                ),
              for (final notice in repo.notifications)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(18),
                      leading: Icon(
                        switch (notice.kind) {
                          PartnerNotificationKind.pickup =>
                            Icons.inventory_2_outlined,
                          PartnerNotificationKind.handover =>
                            Icons.verified_user_outlined,
                          PartnerNotificationKind.recommendation =>
                            Icons.auto_awesome_outlined,
                          PartnerNotificationKind.completed =>
                            Icons.task_alt_rounded,
                          _ => Icons.route_rounded,
                        },
                        color: notice.isRead
                            ? AppColors.textSecondary
                            : AppColors.lime,
                      ),
                      title: Text(notice.title),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${notice.message}\n${DemoFormat.date(notice.createdAt)} · ${notice.isRead ? 'Read' : 'Unread'}',
                        ),
                      ),
                      onTap: () {
                        repo.markRead(notice.id);
                        final order = repo.order(notice.orderId);
                        if (order.status.isActive) {
                          PartnerNavigation.open(
                            context,
                            Scaffold(
                              appBar: AppBar(
                                title: const Text('Active delivery'),
                              ),
                              body: SafeArea(
                                child: ActiveMissionScreen(
                                  onOpenRequests: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          );
                        } else {
                          PartnerNavigation.open(
                            context,
                            RequestDetailsScreen(orderId: notice.orderId),
                          );
                        }
                      },
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
