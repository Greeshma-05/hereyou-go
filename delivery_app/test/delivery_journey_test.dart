import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/app.dart';
import 'package:routerescue_partner/models/delivery_status.dart';
import 'package:routerescue_partner/providers/session_scope.dart';
import 'package:routerescue_partner/screens/app_shell.dart';
import 'package:routerescue_partner/screens/auth/login_screen.dart';
import 'package:routerescue_partner/screens/mission/delivery_success_screen.dart';
import 'package:routerescue_partner/services/account_gateway.dart';
import 'package:routerescue_partner/widgets/request_card.dart';

import 'helpers/memory_onboarding_store.dart';
import 'helpers/test_account_gateway.dart';

void main() {
  Future<void> tap(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final (size, scale, authenticated) in [
    (const Size(390, 844), 1.0, false),
    (const Size(320, 568), 2.0, false),
    (const Size(640, 360), 2.0, false),
    (const Size(390, 844), 1.0, true),
  ]) {
    testWidgets(
      'full delivery journey records one reward at $size and ${scale}x text (signed in: $authenticated)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          RouteRescuePartnerApp(
            onboardingStore: MemoryOnboardingStore(completed: true),
            accountGateway: authenticated
                ? TestAccountGateway()
                : const UnavailableAccountGateway(),
          ),
        );
        await tester.pumpAndSettle();
        if (authenticated) {
          await tester.enterText(
            find.byKey(const ValueKey('login-email')),
            'partner@example.com',
          );
          await tester.enterText(
            find.byKey(const ValueKey('login-password')),
            'example-password',
          );
          await tap(tester, 'Login');
        } else {
          await tap(tester, 'Try Demo Mode');
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.pumpAndSettle();
        final repo = SessionScope.maybeOf(
          tester.element(find.byType(AppShell)),
        )!.repository;
        await tester.ensureVisible(find.byType(Switch).first);
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(repo.partner.isOnline, isTrue);
        await tester.tap(find.byKey(const ValueKey('nav-requests')));
        await tester.pumpAndSettle();
        final request = find.byWidgetPredicate(
          (w) => w is RequestCard && w.order.id == 'RR-2401',
        );
        final details = find.descendant(
          of: request,
          matching: find.widgetWithText(FilledButton, 'View mission'),
        );
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(find.text('Ananya Rao'), findsOneWidget);
        expect(find.textContaining('Expected wait: 3 min'), findsOneWidget);
        await tap(tester, 'Accept request');
        expect(repo.activeMission!.id, 'RR-2401');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-profile')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(
                  FilledButton,
                  authenticated ? 'Sign out' : 'Log out of demo',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const ValueKey('nav-route')));
        await tester.pumpAndSettle();
        expect(find.text('Offline diagram · Not to scale'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('nav-requests')));
        await tester.pumpAndSettle();
        await tap(tester, 'Continue active mission');
        await tap(tester, 'Start mission');
        await tap(tester, 'Confirm arrival at vendor');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm package collection'),
              )
              .onPressed,
          isNull,
        );
        for (final item in ['1 × Travel snack box', '2 × Water bottle']) {
          final check = find.widgetWithText(CheckboxListTile, item);
          await tester.ensureVisible(check);
          await tester.tap(check);
          await tester.pumpAndSettle();
        }
        await tap(tester, 'Confirm package collection');
        await tap(tester, 'Head to handover');
        await tap(tester, 'Confirm arrival at handover');
        await tap(tester, 'Open SafePass');
        final code = find.byKey(const ValueKey('safepass-code'));
        tester.view.viewInsets = FakeViewPadding(bottom: size.height * .4);
        await tester.pumpAndSettle();
        await tester.ensureVisible(code);
        await tester.enterText(code, '000000');
        await tap(tester, 'Verify handover');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.textContaining('demo code is incorrect'), findsOneWidget);
        expect(repo.activeMission!.status, DeliveryStatus.readyForHandover);
        await tester.ensureVisible(code);
        await tester.enterText(code, '246810');
        await tap(tester, 'Verify handover');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(repo.activeMission!.status, DeliveryStatus.handoverConfirmed);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tap(tester, 'Return to active mission');
        await tap(tester, 'Complete delivery');
        expect(find.byType(DeliverySuccessScreen), findsOneWidget);
        expect(repo.completedCount, 1);
        expect(repo.todayEarningsPaise, 12000);
        expect(
          repo.history
              .where((e) => e.order.status == DeliveryStatus.delivered)
              .length,
          1,
        );
        await tap(tester, 'Return to your journey');
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        await tester.tap(find.byKey(const ValueKey('nav-earnings')));
        await tester.pumpAndSettle();
        expect(find.text('₹120'), findsWidgets);
        final history = find.widgetWithText(
          OutlinedButton,
          'View delivery history',
        );
        await tester.ensureVisible(history);
        await tester.tap(history);
        await tester.pumpAndSettle();
        expect(find.text('RR-2401'), findsOneWidget);
        expect(find.text('₹120 demo reward'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-home')));
        await tester.pumpAndSettle();
        expect(repo.activeMission, isNull);
        expect(repo.unreadCount, greaterThan(2));
        await tester.tap(find.byKey(const ValueKey('nav-profile')));
        await tester.pumpAndSettle();
        await tap(tester, authenticated ? 'Sign out' : 'Log out of demo');
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
