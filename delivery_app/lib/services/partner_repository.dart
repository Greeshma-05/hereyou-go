import 'package:flutter/foundation.dart';

import '../models/delivery_request.dart';
import '../models/delivery_partner.dart';
import '../models/delivery_status.dart';
import '../models/delivery_history_entry.dart';
import '../models/partner_notification.dart';
import '../models/stop_fit_result.dart';

abstract class PartnerRepository extends ChangeNotifier {
  DeliveryPartner get partner;
  List<DeliveryRequest> get requests;
  DeliveryRequest? get activeMission;
  List<DeliveryHistoryEntry> get history;
  List<PartnerNotification> get notifications;
  DateTime get demoNow;
  int get todayEarningsPaise;
  int get weeklyEarningsPaise;
  int get completedCount;
  int get unreadCount;
  DeliveryRequest? get recommended;
  DeliveryRequest order(String id);
  StopFitResult fit(DeliveryRequest order);
  void setOnline(bool online);
  void setPreferences({bool? notificationsEnabled, bool? hapticsEnabled});
  void accept(String id);
  void reject(String id);
  void advance(String id, DeliveryStatus expected);
  void verifyHandover(String id, String code);
  void complete(String id);
  void markRead(String id);
  void markAllRead();
}
