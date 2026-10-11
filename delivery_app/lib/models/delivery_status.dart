enum DeliveryStatus {
  pending,
  accepted,
  travelingToPickup,
  arrivedAtVendor,
  pickedUp,
  inTransit,
  readyForHandover,
  handoverConfirmed,
  delivered,
  rejected,
  cancelled,
  failed,
}

extension DeliveryStatusDetails on DeliveryStatus {
  String get label => switch (this) {
    DeliveryStatus.pending => 'New request',
    DeliveryStatus.accepted => 'Request accepted',
    DeliveryStatus.travelingToPickup => 'Traveling to pickup',
    DeliveryStatus.arrivedAtVendor => 'Arrived at vendor',
    DeliveryStatus.pickedUp => 'Pickup confirmed',
    DeliveryStatus.inTransit => 'Traveling to handover',
    DeliveryStatus.readyForHandover => 'Ready for handover',
    DeliveryStatus.handoverConfirmed => 'Handover confirmed',
    DeliveryStatus.delivered => 'Delivery completed',
    DeliveryStatus.rejected => 'Rejected',
    DeliveryStatus.cancelled => 'Cancelled',
    DeliveryStatus.failed => 'Failed',
  };

  bool get isActive =>
      index >= DeliveryStatus.accepted.index &&
      index <= DeliveryStatus.handoverConfirmed.index;
  bool get isTerminal =>
      this == DeliveryStatus.delivered ||
      this == DeliveryStatus.rejected ||
      this == DeliveryStatus.cancelled ||
      this == DeliveryStatus.failed;
}
