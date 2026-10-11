import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/core/theme/app_theme.dart';
import 'package:routerescue_partner/models/delivery_status.dart';
import 'package:routerescue_partner/models/demo_session.dart';
import 'package:routerescue_partner/providers/session_scope.dart';
import 'package:routerescue_partner/screens/app_shell.dart';
import 'package:routerescue_partner/services/mock_partner_repository.dart';
import 'package:routerescue_partner/widgets/request_card.dart';

void main() {
  Future<void> openTab(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<MockPartnerRepository> render(WidgetTester tester) async {
    final repo = MockPartnerRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SessionScope(
          session: DemoSession(repository: repo),
          child: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'search, rejection and history filters agree with repository state',
    (tester) async {
      final repo = await render(tester);
      await openTab(tester, 'nav-requests');
      await tester.enterText(find.byType(TextField), 'RR-2402');
      await tester.pumpAndSettle();
      expect(find.byType(RequestCard), findsOneWidget);
      final view = find.widgetWithText(FilledButton, 'View mission');
      await tester.ensureVisible(view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      final reject = find.widgetWithText(OutlinedButton, 'Reject request');
      await tester.ensureVisible(reject);
      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(repo.order('RR-2402').status, DeliveryStatus.rejected);
      expect(find.widgetWithText(FilledButton, 'Accept request'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RequestCard), findsNothing);
      final all = find.widgetWithText(ChoiceChip, 'All');
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.byType(RequestCard), findsOneWidget);
      await openTab(tester, 'nav-profile');
      final history = find.widgetWithText(ListTile, 'Delivery history');
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rejected'));
      await tester.pumpAndSettle();
      expect(find.text('RR-2402'), findsOneWidget);
      expect(find.text('RR-2399'), findsNothing);
      expect(repo.todayEarningsPaise, 0);
    },
  );

  testWidgets(
    'notification navigation, read state and profile settings are interactive',
    (tester) async {
      final repo = await render(tester);
      await tester.tap(find.byTooltip('Notifications, 2 unread'));
      await tester.pumpAndSettle();
      final notice = find.widgetWithText(ListTile, 'StopFit found a match');
      await tester.ensureVisible(notice);
      await tester.tap(notice);
      await tester.pumpAndSettle();
      expect(repo.unreadCount, 1);
      expect(find.text('RR-2401'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(repo.unreadCount, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, 'nav-profile');
      for (final label in [
        'Available for requests',
        'Demo notifications',
        'Haptic feedback',
      ]) {
        final control = find.widgetWithText(SwitchListTile, label);
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
      }
      expect(repo.partner.isOnline, isTrue);
      expect(repo.partner.notificationsEnabled, isFalse);
      expect(repo.partner.hapticsEnabled, isFalse);
      await openTab(tester, 'nav-home');
      expect(find.text('Demo mode · Online'), findsOneWidget);
      expect(find.text('ONLINE · READY FOR REQUESTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
