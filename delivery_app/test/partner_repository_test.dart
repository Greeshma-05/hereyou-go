import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/models/delivery_status.dart';
import 'package:routerescue_partner/models/stop_fit_result.dart';
import 'package:routerescue_partner/services/mock_partner_repository.dart';

void main() {
  late MockPartnerRepository repo;
  setUp(() => repo = MockPartnerRepository());
  tearDown(() => repo.dispose());

  void reachHandover(String id) {
    repo.accept(id);
    for (final stage in [
      DeliveryStatus.accepted,
      DeliveryStatus.travelingToPickup,
      DeliveryStatus.arrivedAtVendor,
      DeliveryStatus.pickedUp,
      DeliveryStatus.inTransit,
    ]) {
      repo.advance(id, stage);
    }
  }

  test('StopFit derives four classifications and explains demo timing', () {
    expect(
      repo.fit(repo.order('RR-2401')).classification,
      StopFitClassification.excellent,
    );
    expect(repo.fit(repo.order('RR-2401')).estimatedMinutes, 13);
    expect(repo.fit(repo.order('RR-2401')).marginMinutes, 22);
    expect(
      repo.fit(repo.order('RR-2402')).classification,
      StopFitClassification.good,
    );
    expect(
      repo.fit(repo.order('RR-2403')).classification,
      StopFitClassification.tight,
    );
    expect(repo.fit(repo.order('RR-2403')).marginMinutes, -2);
    expect(
      repo.fit(repo.order('RR-2404')).classification,
      StopFitClassification.mismatch,
    );
    expect(repo.recommended!.id, 'RR-2401');
  });

  test('offline, duplicate and second concurrent acceptance are rejected', () {
    expect(() => repo.accept('RR-2401'), throwsA(isA<DemoActionException>()));
    repo.setOnline(true);
    repo.accept('RR-2401');
    expect(() => repo.accept('RR-2401'), throwsA(isA<DemoActionException>()));
    expect(() => repo.accept('RR-2402'), throwsA(isA<DemoActionException>()));
    expect(repo.activeMission!.id, 'RR-2401');
    expect(repo.order('RR-2402').status, DeliveryStatus.pending);
    repo.setOnline(false);
    repo.advance('RR-2401', DeliveryStatus.accepted);
    expect(repo.activeMission!.status, DeliveryStatus.travelingToPickup);
  });

  test('rejected request cannot be accepted from a stale screen', () {
    repo.setOnline(true);
    repo.reject('RR-2401');
    expect(() => repo.accept('RR-2401'), throwsA(isA<DemoActionException>()));
    expect(() => repo.reject('RR-2401'), throwsA(isA<DemoActionException>()));
    expect(repo.recommended!.id, 'RR-2402');
    expect(repo.history.where((e) => e.order.id == 'RR-2401').length, 1);
    expect(repo.todayEarningsPaise, 0);
  });

  test('wrong stages, stale progress events and early completion cannot skip pickup', () {
    repo.setOnline(true);
    repo.accept('RR-2401');
    expect(
      () => repo.advance('RR-2401', DeliveryStatus.pickedUp),
      throwsA(isA<DemoActionException>()),
    );
    expect(
      () => repo.verifyHandover('RR-2401', '246810'),
      throwsA(isA<DemoActionException>()),
    );
    expect(() => repo.complete('RR-2401'), throwsA(isA<DemoActionException>()));
    repo.advance('RR-2401', DeliveryStatus.accepted);
    expect(
      () => repo.advance('RR-2401', DeliveryStatus.accepted),
      throwsA(isA<DemoActionException>()),
    );
    expect(repo.todayEarningsPaise, 0);
  });

  test(
    'SafePass is order-specific, rejects wrong codes and prevents reuse',
    () {
      repo.setOnline(true);
      reachHandover('RR-2401');
      for (final code in ['', '123', '000000', '135790']) {
        expect(
          () => repo.verifyHandover('RR-2401', code),
          throwsA(isA<DemoActionException>()),
        );
      }
      expect(repo.activeMission!.status, DeliveryStatus.readyForHandover);
      repo.verifyHandover('RR-2401', '246810');
      expect(repo.activeMission!.status, DeliveryStatus.handoverConfirmed);
      expect(
        () => repo.verifyHandover('RR-2401', '246810'),
        throwsA(isA<DemoActionException>()),
      );
      expect(repo.todayEarningsPaise, 0);
    },
  );

  test('completion records one history reward and cannot be applied twice', () {
    repo.setOnline(true);
    reachHandover('RR-2401');
    repo.verifyHandover('RR-2401', '246810');
    repo.complete('RR-2401');
    final notices = repo.notifications.length;
    expect(() => repo.complete('RR-2401'), throwsA(isA<DemoActionException>()));
    expect(
      () => repo.verifyHandover('RR-2401', '246810'),
      throwsA(isA<DemoActionException>()),
    );
    expect(repo.notifications.length, notices);
    expect(repo.activeMission, isNull);
    expect(repo.completedCount, 1);
    expect(repo.todayEarningsPaise, 12000);
    expect(repo.weeklyEarningsPaise, 12000);
    expect(repo.history.where((e) => e.order.id == 'RR-2401').length, 1);
    reachHandover('RR-2402');
    repo.verifyHandover('RR-2402', '135790');
    repo.complete('RR-2402');
    expect(repo.completedCount, 2);
    expect(repo.todayEarningsPaise, 28500);
  });

  test('notifications and preferences reflect only actual demo actions', () {
    final initialCount = repo.unreadCount;
    repo.markRead(repo.notifications.first.id);
    repo.markRead(repo.notifications.first.id);
    expect(repo.unreadCount, initialCount - 1);
    repo.markAllRead();
    expect(repo.unreadCount, 0);
    repo.setOnline(true);
    repo.accept('RR-2401');
    expect(repo.unreadCount, 1);
    repo.setPreferences(notificationsEnabled: false, hapticsEnabled: false);
    repo.advance('RR-2401', DeliveryStatus.accepted);
    repo.advance('RR-2401', DeliveryStatus.travelingToPickup);
    expect(repo.unreadCount, 1);
    expect(repo.partner.hapticsEnabled, isFalse);
  });
}
