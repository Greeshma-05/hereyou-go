import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/app.dart';
import 'package:routerescue_partner/providers/session_scope.dart';
import 'package:routerescue_partner/screens/app_shell.dart';
import 'package:routerescue_partner/screens/auth/login_screen.dart';
import 'package:routerescue_partner/screens/dashboard/dashboard_screen.dart';
import 'package:routerescue_partner/screens/onboarding/onboarding_screen.dart';
import 'package:routerescue_partner/screens/splash/splash_screen.dart';
import 'package:routerescue_partner/widgets/onboarding_indicator.dart';

import 'helpers/memory_onboarding_store.dart';

void main() {
  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first launch supports next, swipe, Android Back and completion',
    (tester) async {
      final store = MemoryOnboardingStore();
      await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await tapButton(tester, 'Next');
      expect(
        tester
            .widget<OnboardingIndicator>(find.byType(OnboardingIndicator))
            .index,
        1,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OnboardingIndicator>(find.byType(OnboardingIndicator))
            .index,
        0,
      );

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OnboardingIndicator>(find.byType(OnboardingIndicator))
            .index,
        1,
      );
      await tapButton(tester, 'Next');
      expect(find.text('Deliver with Confidence'), findsOneWidget);
      await tapButton(tester, 'Get Started');
      expect(store.completed, isTrue);
      expect(store.writes, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets('Skip persists once and a fresh launch goes to login', (
    tester,
  ) async {
    final store = MemoryOnboardingStore()..saveGate = Completer<void>();
    await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    expect(store.writes, 1);
    expect(find.text('Saving progress'), findsOneWidget);
    store.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets(
    'returning user enters an offline demo, keeps tabs, and loses session on restart',
    (tester) async {
      final store = MemoryOnboardingStore(completed: true);
      await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tapButton(tester, 'Try Demo Mode');
      // The brief operation uses a timer, not an animation that pumpAndSettle waits for.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DashboardScreen).hitTestable(), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Demo mode · Offline'), findsOneWidget);
      final session = SessionScope.maybeOf(
        tester.element(find.byType(AppShell)),
      )!;
      expect(session.name, 'Demo Delivery Partner');
      expect(session.accountType, 'Demo');
      expect(session.isOnline, isFalse);

      for (final (key, index) in [
        ('nav-requests', 1),
        ('nav-route', 2),
        ('nav-earnings', 3),
        ('nav-profile', 4),
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
      }
      expect(find.text('Demo Delivery Partner'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SessionScope), findsNothing);
    },
  );

  testWidgets('storage failure offers retry or continuation without saving', (
    tester,
  ) async {
    final store = MemoryOnboardingStore()
      ..failRead = true
      ..failWrite = true;
    await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save your progress'), findsOneWidget);
    expect(store.completed, isFalse);
    await tester.tap(find.text('Continue to login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'logout clears demo access, keeps onboarding and allows re-entry',
    (tester) async {
      final store = MemoryOnboardingStore();
      await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();

      for (var attempt = 0; attempt < 2; attempt++) {
        await tapButton(tester, 'Try Demo Mode');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
        );
        expect(
          SessionScope.maybeOf(tester.element(find.byType(AppShell))),
          isNotNull,
        );

        await tester.tap(find.byKey(const ValueKey('nav-profile')));
        await tester.pumpAndSettle();
        final logout = find.widgetWithText(FilledButton, 'Log out of demo');
        await tester.ensureVisible(logout);
        await tester.tap(logout);
        // A second event before the next frame must not resurrect the shell.
        await tester.tap(logout);
        await tester.pumpAndSettle();
        expect(find.byType(SessionScope), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(store.completed, isTrue);
        expect(store.writes, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AppShell), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion skips the splash animation', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      RouteRescuePartnerApp(
        onboardingStore: MemoryOnboardingStore(completed: true),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
