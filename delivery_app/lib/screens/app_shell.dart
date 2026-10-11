import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/partner_navigation.dart';
import '../models/demo_session.dart';
import '../providers/session_scope.dart';
import '../services/account_gateway.dart';
import '../widgets/cinematic_background.dart';
import '../widgets/demo_session_banner.dart';
import '../widgets/floating_partner_navigation.dart';
import 'dashboard/dashboard_screen.dart';
import 'auth/firebase_account_screen.dart';
import 'earnings/earnings_screen.dart';
import 'mission/active_mission_screen.dart';
import 'map/route_pulse_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';
import 'requests/requests_screen.dart';
import 'requests/request_details_screen.dart';

enum AppDestination { home, requests, routePulse, earnings, profile }

class AppShell extends StatefulWidget {
  const AppShell({this.onLogout, this.accountGateway, super.key});
  final Future<void> Function()? onLogout;
  final AccountGateway? accountGateway;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DemoSession? _localSession;
  AppDestination _destination = AppDestination.home;
  bool _signingOut = false;
  String? _logoutError;

  Future<void> _logout() async {
    if (_signingOut || widget.onLogout == null) return;
    setState(() {
      _signingOut = true;
      _logoutError = null;
    });
    try {
      await widget.onLogout!();
    } catch (_) {
      if (mounted) {
        setState(() => _logoutError = 'Could not sign out. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _selectDestination(AppDestination destination) {
    if (_destination == destination) return;
    setState(() => _destination = destination);
  }

  void _openRequests() => _selectDestination(AppDestination.requests);
  void _openMission(BuildContext context) {
    _openRequests();
    PartnerNavigation.open(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Active delivery')),
        body: SafeArea(
          child: ActiveMissionScreen(
            onOpenRequests: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (SessionScope.maybeOf(context) == null) {
      return SessionScope(
        session: _localSession ??= DemoSession(),
        child: Builder(builder: _buildShell),
      );
    }
    return _buildShell(context);
  }

  @override
  void dispose() {
    _localSession?.repository.dispose();
    super.dispose();
  }

  Widget _buildShell(BuildContext context) {
    final session = SessionScope.maybeOf(context)!;
    final screens = [
      DashboardScreen(
        onOpenNotifications: () =>
            PartnerNavigation.open(context, const NotificationsScreen()),
        onOpenOrder: (id) =>
            PartnerNavigation.open(context, RequestDetailsScreen(orderId: id)),
        onOpenRequests: _openRequests,
        onOpenProfile: () => _selectDestination(AppDestination.profile),
        onOpenMap: () => _selectDestination(AppDestination.routePulse),
        onOpenMission: () => _openMission(context),
      ),
      const RequestsScreen(),
      const RoutePulseScreen(),
      const EarningsScreen(),
      ProfileScreen(
        onLogout: widget.onLogout == null ? null : _logout,
        isSigningOut: _signingOut,
        logoutError: _logoutError,
        onOpenAccount: session.account != null && widget.accountGateway != null
            ? () => PartnerNavigation.open(
                context,
                FirebaseAccountScreen(
                  account: session.account!,
                  gateway: widget.accountGateway!,
                ),
              )
            : null,
      ),
    ];
    return AbsorbPointer(
      absorbing: _signingOut,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlayStyle,
        child: PopScope<Object?>(
          canPop: !_signingOut && _destination == AppDestination.home,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !_signingOut) {
              _selectDestination(AppDestination.home);
            }
          },
          child: Scaffold(
            body: CinematicBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    DemoSessionBanner(session: session),
                    // Keep tabs mounted and suspend animations in inactive destinations.
                    Expanded(
                      child: IndexedStack(
                        index: _destination.index,
                        children: [
                          for (var i = 0; i < screens.length; i++)
                            TickerMode(
                              enabled: i == _destination.index,
                              child: screens[i],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: FloatingPartnerNavigation(
              index: _destination.index,
              onSelected: (index) =>
                  _selectDestination(AppDestination.values[index]),
            ),
          ),
        ),
      ),
    );
  }
}
