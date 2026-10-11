import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/app.dart';
import 'package:routerescue_partner/screens/auth/login_screen.dart';

import 'helpers/memory_onboarding_store.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('storage recovery stays reachable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final store = MemoryOnboardingStore()..failWrite = true;
      await tester.pumpWidget(RouteRescuePartnerApp(onboardingStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Could not save your progress'),
        findsOneWidget,
      );

      final continueButton = find.widgetWithText(
        TextButton,
        'Continue to login',
      );
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      expect(continueButton.hitTestable(), findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(store.completed, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
