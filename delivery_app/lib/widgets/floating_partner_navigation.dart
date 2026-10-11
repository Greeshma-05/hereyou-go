import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'glass_panel.dart';

class FloatingPartnerNavigation extends StatelessWidget {
  const FloatingPartnerNavigation({
    required this.index,
    required this.onSelected,
    super.key,
  });
  final int index;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: GlassPanel(
      padding: EdgeInsets.zero,
      child: NavigationBarTheme(
        data: Theme.of(context).navigationBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          height: 78,
          indicatorColor: AppColors.lime,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? AppColors.background
                  : AppColors.textSecondary,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 10,
              height: 1.2,
              color: states.contains(WidgetState.selected)
                  ? AppColors.lime
                  : AppColors.textSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelected,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          destinations: const [
            NavigationDestination(
              key: ValueKey('nav-home'),
              tooltip: 'Mission Control',
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Control',
            ),
            NavigationDestination(
              key: ValueKey('nav-requests'),
              tooltip: 'Deliveries',
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Deliveries',
            ),
            NavigationDestination(
              key: ValueKey('nav-route'),
              tooltip: 'RoutePulse',
              icon: Icon(Icons.near_me_outlined),
              selectedIcon: Icon(Icons.near_me_rounded),
              label: 'RoutePulse',
            ),
            NavigationDestination(
              key: ValueKey('nav-earnings'),
              tooltip: 'Earnings',
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Earnings',
            ),
            NavigationDestination(
              key: ValueKey('nav-profile'),
              tooltip: 'Profile',
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),
  );
}
