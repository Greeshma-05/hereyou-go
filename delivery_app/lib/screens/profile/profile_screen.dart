import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/partner_navigation.dart';
import '../../providers/session_scope.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../history/history_screen.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    this.onLogout,
    this.onOpenAccount,
    this.isSigningOut = false,
    this.logoutError,
    super.key,
  });
  final VoidCallback? onLogout;
  final VoidCallback? onOpenAccount;
  final bool isSigningOut;
  final String? logoutError;
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.repositoryOf(context);
    final session = SessionScope.maybeOf(context)!;
    final partner = repo.partner;
    final text = Theme.of(context).textTheme;
    return AppPage(
      storageId: 'profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'THE PERSON BEHIND THE JOURNEY',
            style: text.labelSmall?.copyWith(color: AppColors.lime),
          ),
          const SizedBox(height: 12),
          Text('Your partner space.', style: text.headlineLarge),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.lime,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 36,
                    color: AppColors.background,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  partner.name,
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  partner.email,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        session.isAuthenticated ? 'SIGNED IN' : 'DEMO ACCOUNT',
                      ),
                    ),
                    Chip(label: Text('★ ${partner.demoRating} demo rating')),
                    Chip(label: Text('${repo.completedCount} completed')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (session.account?.setupMessage != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(session.account!.setupMessage!),
            ),
            const SizedBox(height: 20),
          ],
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Available for requests'),
                  subtitle: Text(
                    partner.isOnline
                        ? 'Online in this demo only'
                        : 'Offline · Not accepting new requests',
                  ),
                  value: partner.isOnline,
                  onChanged: repo.setOnline,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Demo notifications'),
                  subtitle: const Text(
                    'Create local updates for future actions',
                  ),
                  value: partner.notificationsEnabled,
                  onChanged: (value) =>
                      repo.setPreferences(notificationsEnabled: value),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Haptic feedback'),
                  subtitle: const Text('Device feedback for mission actions'),
                  value: partner.hapticsEnabled,
                  onChanged: (value) =>
                      repo.setPreferences(hapticsEnabled: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (onOpenAccount != null)
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Account details'),
                    subtitle: const Text(
                      'Signed-in identity and saved profile',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onOpenAccount,
                  ),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('Delivery history'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      PartnerNavigation.open(context, const HistoryScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: const Text('Notification inbox'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => PartnerNavigation.open(
                    context,
                    const NotificationsScreen(),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About RouteRescue'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'RouteRescue Partner',
                    applicationVersion: '0.1.0 · Demo',
                    applicationIcon: const Icon(
                      Icons.route_rounded,
                      color: AppColors.lime,
                    ),
                    children: [
                      const Text(
                        'Every delivery moves a journey forward.\n\nA route-aware essentials delivery app for travelers. Account authentication uses Firebase. Orders, locations, StopFit estimates, ratings, SafePass codes and earnings are simulated. Live dispatch, payments and tracking are not connected.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (repo.activeMission != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Finish ${repo.activeMission!.id} before logging out. You can go offline and still complete this mission.',
                style: const TextStyle(color: AppColors.warningText),
              ),
            ),
          AppButton(
            label: session.isAuthenticated ? 'Sign out' : 'Log out of demo',
            icon: Icons.logout_rounded,
            isLoading: isSigningOut,
            loadingLabel: 'Signing out',
            onPressed: repo.activeMission == null && !isSigningOut
                ? onLogout
                : null,
          ),
          if (logoutError != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                logoutError!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Logout or restarting the app resets demo orders, rewards and preferences. Onboarding completion is kept. Availability is local and is not synced to a server.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
