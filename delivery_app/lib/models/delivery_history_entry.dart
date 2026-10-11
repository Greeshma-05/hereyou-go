import 'delivery_request.dart';

class DeliveryHistoryEntry {
  const DeliveryHistoryEntry(this.order, this.occurredAt);
  final DeliveryRequest order;
  final DateTime occurredAt;
}
