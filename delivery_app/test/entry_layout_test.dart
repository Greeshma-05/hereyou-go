import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/app.dart';
import 'package:routerescue_partner/screens/auth/login_screen.dart';
import 'package:routerescue_partner/widgets/onboarding_indicator.dart';

import 'helpers/memory_onboarding_store.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(412, 915),
    const Size(640, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'entry flow fits $size at ${scale}x, including the keyboard',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            RouteRescuePartnerApp(onboardingStore: MemoryOnboardingStore()),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          for (var page = 0; page < 3; page++) {
            expect(
              tester
                  .widget<OnboardingIndicator>(find.byType(OnboardingIndicator))
                  .index,
              page,
            );
            expect(tester.takeException(), isNull);
            final label = page == 2 ? 'Get Started' : 'Next';
            await tester.tap(find.widgetWithText(FilledButton, label));
            await tester.pumpAndSettle();
          }

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          final password = find.byKey(const ValueKey('login-password'));
          await tester.ensureVisible(password);
          tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.4);
          await tester.enterText(password, 'local-test-value');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final login = find.widgetWithText(FilledButton, 'Login');
          await tester.ensureVisible(login);
          await tester.pumpAndSettle();
          final bounds = tester.getRect(login);
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(size.height * 0.6 + 1));
          expect(login.hitTestable(), findsOneWidget);

          tester.view.resetViewInsets();
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          final demo = find.widgetWithText(FilledButton, 'Try Demo Mode');
          await tester.ensureVisible(demo);
          await tester.tap(demo);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.text('Demo mode · Offline'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(const ValueKey('nav-profile')));
          await tester.pumpAndSettle();
          final logout = find.widgetWithText(FilledButton, 'Log out of demo');
          await tester.ensureVisible(logout);
          await tester.pumpAndSettle();
          expect(logout.hitTestable(), findsOneWidget);
          await tester.tap(logout);
          await tester.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
