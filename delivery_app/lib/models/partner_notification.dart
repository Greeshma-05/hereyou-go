enum PartnerNotificationKind {
  opportunity,
  accepted,
  pickup,
  handover,
  recommendation,
  completed,
}

class PartnerNotification {
  const PartnerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    required this.orderId,
    required this.createdAt,
    this.isRead = false,
  });
  final String id;
  final String title;
  final String message;
  final PartnerNotificationKind kind;
  final String orderId;
  final DateTime createdAt;
  final bool isRead;
  PartnerNotification markRead() => PartnerNotification(
    id: id,
    title: title,
    message: message,
    kind: kind,
    orderId: orderId,
    createdAt: createdAt,
    isRead: true,
  );
}
