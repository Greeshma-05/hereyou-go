import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/app.dart';

import 'helpers/memory_onboarding_store.dart';

void main() {
  testWidgets(
    'entry and demo controls have labels, contrast and Android targets',
    (tester) async {
      // Measure complete controls, rather than clipped portions at a scroll edge.
      // Real phone sizes and text scaling are covered by the layout tests.
      tester.view.physicalSize = const Size(412, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      Future<void> checkVisibleControls() async {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }

      try {
        await tester.pumpWidget(
          RouteRescuePartnerApp(onboardingStore: MemoryOnboardingStore()),
        );
        await tester.pumpAndSettle();
        await checkVisibleControls();
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();
        await checkVisibleControls();

        final demo = find.widgetWithText(FilledButton, 'Try Demo Mode');
        await tester.ensureVisible(demo);
        await tester.pumpAndSettle();
        await checkVisibleControls();
        await tester.tap(demo);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        for (final key in [
          'nav-home',
          'nav-requests',
          'nav-route',
          'nav-earnings',
          'nav-profile',
        ]) {
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
          await checkVisibleControls();
        }
        final logout = find.widgetWithText(FilledButton, 'Log out of demo');
        await tester.ensureVisible(logout);
        await tester.pumpAndSettle();
        await checkVisibleControls();
      } finally {
        semantics.dispose();
      }
    },
  );
}
