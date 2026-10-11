import '../data/demo_data.dart';
import '../models/delivery_history_entry.dart';
import '../models/delivery_partner.dart';
import '../models/delivery_request.dart';
import '../models/delivery_status.dart';
import '../models/partner_notification.dart';
import '../models/stop_fit_result.dart';
import 'partner_repository.dart';
import 'stop_fit_service.dart';

class DemoActionException implements Exception {
  const DemoActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MockPartnerRepository extends PartnerRepository {
  MockPartnerRepository({List<DeliveryRequest>? seed, DeliveryPartner? partner})
    : _partner = partner ?? const DeliveryPartner() {
    for (final request in seed ?? DemoData.requests) {
      _orders[request.id] = request;
      if (request.status.isTerminal) {
        _terminalTimes[request.id] = DemoData.startTime.subtract(
          const Duration(days: 1),
        );
      }
    }
    if (_orders.containsKey('RR-2401')) {
      _addNotification(
        'A journey needs you',
        'RR-2401 is available near Kengeri. Go online to accept.',
        PartnerNotificationKind.opportunity,
        'RR-2401',
      );
      _addNotification(
        'StopFit found a match',
        'RR-2401 adds just 0.6 km of demo detour.',
        PartnerNotificationKind.recommendation,
        'RR-2401',
      );
    }
  }
  final Map<String, DeliveryRequest> _orders = {};
  final Map<String, DateTime> _terminalTimes = {};
  final List<PartnerNotification> _notifications = [];
  DeliveryPartner _partner;
  int _event = 0;
  final _stopFit = const StopFitService();
  @override
  DeliveryPartner get partner => _partner;
  @override
  DateTime get demoNow => DemoData.startTime.add(Duration(minutes: _event));
  @override
  List<DeliveryRequest> get requests => List.unmodifiable(_orders.values);
  @override
  List<PartnerNotification> get notifications =>
      List.unmodifiable(_notifications.reversed);
  @override
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  @override
  int get completedCount =>
      _orders.values.where((o) => o.status == DeliveryStatus.delivered).length;
  @override
  DeliveryRequest? get activeMission {
    for (final order in _orders.values) {
      if (order.status.isActive) return order;
    }
    return null;
  }

  @override
  List<DeliveryHistoryEntry> get history {
    final entries = _terminalTimes.entries
        .map((e) => DeliveryHistoryEntry(order(e.key), e.value))
        .toList();
    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(entries);
  }

  int _earningsSince(DateTime start) => history
      .where(
        (e) =>
            e.order.status == DeliveryStatus.delivered &&
            !e.occurredAt.isBefore(start) &&
            !e.occurredAt.isAfter(demoNow),
      )
      .fold(0, (sum, e) => sum + e.order.rewardPaise);
  @override
  int get todayEarningsPaise =>
      _earningsSince(DateTime(demoNow.year, demoNow.month, demoNow.day));
  @override
  int get weeklyEarningsPaise => _earningsSince(
    DateTime(
      demoNow.year,
      demoNow.month,
      demoNow.day,
    ).subtract(const Duration(days: 6)),
  );
  @override
  StopFitResult fit(DeliveryRequest order) => _stopFit.evaluate(order);
  @override
  DeliveryRequest? get recommended {
    final candidates = requests
        .where((o) => o.status == DeliveryStatus.pending)
        .toList();
    candidates.sort((a, b) {
      final rank = fit(a).classification.index
          .compareTo(fit(b).classification.index);
      return rank != 0 ? rank : a.detourKm.compareTo(b.detourKm);
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  DeliveryRequest order(String id) =>
      _orders[id] ??
      (throw const DemoActionException('This request is no longer available.'));
  @override
  void setOnline(bool online) {
    _partner = _partner.copyWith(isOnline: online);
    notifyListeners();
  }

  @override
  void setPreferences({bool? notificationsEnabled, bool? hapticsEnabled}) {
    _partner = _partner.copyWith(
      notificationsEnabled: notificationsEnabled,
      hapticsEnabled: hapticsEnabled,
    );
    notifyListeners();
  }

  void _require(String id, DeliveryStatus expected) {
    if (order(id).status != expected) {
      throw const DemoActionException(
        'This mission has changed. Review its current status.',
      );
    }
  }

  void _setStatus(String id, DeliveryStatus status) {
    _orders[id] = order(id).withStatus(status);
    _event++;
    if (status.isTerminal) _terminalTimes.putIfAbsent(id, () => demoNow);
  }

  @override
  void accept(String id) {
    _require(id, DeliveryStatus.pending);
    if (!_partner.isOnline) {
      throw const DemoActionException('Go online before accepting a request.');
    }
    if (activeMission != null) {
      throw const DemoActionException(
        'Finish your active mission before accepting another.',
      );
    }
    _setStatus(id, DeliveryStatus.accepted);
    _addNotification(
      'Mission accepted',
      'Your next stop is ${order(id).pickup.name}.',
      PartnerNotificationKind.accepted,
      id,
    );
    notifyListeners();
  }

  @override
  void reject(String id) {
    _require(id, DeliveryStatus.pending);
    _setStatus(id, DeliveryStatus.rejected);
    notifyListeners();
  }

  @override
  void advance(String id, DeliveryStatus expected) {
    _require(id, expected);
    final next = switch (expected) {
      DeliveryStatus.accepted => DeliveryStatus.travelingToPickup,
      DeliveryStatus.travelingToPickup => DeliveryStatus.arrivedAtVendor,
      DeliveryStatus.arrivedAtVendor => DeliveryStatus.pickedUp,
      DeliveryStatus.pickedUp => DeliveryStatus.inTransit,
      DeliveryStatus.inTransit => DeliveryStatus.readyForHandover,
      _ => throw const DemoActionException(
        'Use the required verification step to continue.',
      ),
    };
    _setStatus(id, next);
    if (next == DeliveryStatus.arrivedAtVendor) {
      _addNotification(
        'Check your package',
        'Confirm every item before leaving the pickup point.',
        PartnerNotificationKind.pickup,
        id,
      );
    }
    notifyListeners();
  }

  @override
  void verifyHandover(String id, String code) {
    _require(id, DeliveryStatus.readyForHandover);
    if (code.trim() != order(id).demoCode) {
      throw const DemoActionException(
        'That demo code is incorrect. Check the code shown below.',
      );
    }
    _setStatus(id, DeliveryStatus.handoverConfirmed);
    _addNotification(
      'Handover confirmed',
      'SafePass demo check passed. Complete the delivery to record its reward.',
      PartnerNotificationKind.handover,
      id,
    );
    notifyListeners();
  }

  @override
  void complete(String id) {
    _require(id, DeliveryStatus.handoverConfirmed);
    _setStatus(id, DeliveryStatus.delivered);
    _addNotification(
      'Every delivery moves a journey forward',
      'Your demo reward has been recorded once in Earnings.',
      PartnerNotificationKind.completed,
      id,
    );
    notifyListeners();
  }

  void _addNotification(
    String title,
    String message,
    PartnerNotificationKind kind,
    String orderId,
  ) {
    if (!_partner.notificationsEnabled) return;
    _notifications.add(
      PartnerNotification(
        id: 'notice-${_notifications.length + 1}',
        title: title,
        message: message,
        kind: kind,
        orderId: orderId,
        createdAt: demoNow,
      ),
    );
  }

  @override
  void markRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].isRead) return;
    _notifications[index] = _notifications[index].markRead();
    notifyListeners();
  }

  @override
  void markAllRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].markRead();
    }
    notifyListeners();
  }
}
