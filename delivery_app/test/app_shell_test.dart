import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/core/theme/app_theme.dart';
import 'package:routerescue_partner/screens/app_shell.dart';
import 'package:routerescue_partner/screens/dashboard/dashboard_screen.dart';
import 'package:routerescue_partner/screens/earnings/earnings_screen.dart';
import 'package:routerescue_partner/screens/map/route_pulse_screen.dart';
import 'package:routerescue_partner/screens/profile/profile_screen.dart';
import 'package:routerescue_partner/screens/requests/requests_screen.dart';

void main() {
  Future<void> openTab(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('all tabs select their screen and Android back returns home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AppShell()),
    );

    final destinations = <(String, Type)>[
      ('nav-requests', RequestsScreen),
      ('nav-route', RoutePulseScreen),
      ('nav-earnings', EarningsScreen),
      ('nav-profile', ProfileScreen),
      ('nav-home', DashboardScreen),
    ];

    for (final (key, screenType) in destinations) {
      await openTab(tester, key);
      expect(find.byType(screenType).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await openTab(tester, 'nav-profile');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen).hitTestable(), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets(
    'dashboard action opens Requests and keeps the dashboard scroll',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AppShell()),
      );

      final dashboard = find.byType(DashboardScreen);
      final scrollable = find.descendant(
        of: dashboard,
        matching: find.byType(Scrollable),
      );
      final action = find.descendant(
        of: dashboard,
        matching: find.widgetWithText(FilledButton, 'Explore requests'),
      );
      await tester.scrollUntilVisible(action, 120, scrollable: scrollable);
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scrollable).position;
      final savedOffset = position.pixels;
      expect(savedOffset, greaterThan(0));

      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(RequestsScreen).hitTestable(), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await openTab(tester, 'nav-home');
      expect(position.pixels, closeTo(savedOffset, 0.01));

      await openTab(tester, 'nav-route');
      final missionAction = find.widgetWithText(FilledButton, 'View mission');
      await tester.ensureVisible(missionAction);
      await tester.tap(missionAction);
      await tester.pumpAndSettle();
      expect(find.text('A LITTLE DETOUR.\nA BIG DIFFERENCE.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(412, 915),
    const Size(640, 360),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('all screens fit $size with text scale $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const AppShell()),
        );

        for (final key in [
          'nav-home',
          'nav-requests',
          'nav-route',
          'nav-earnings',
          'nav-profile',
        ]) {
          await openTab(tester, key);
          expect(tester.takeException(), isNull);
          final scrollable = find.byType(Scrollable).first;
          final state = tester.state<ScrollableState>(scrollable);
          state.position.jumpTo(state.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
