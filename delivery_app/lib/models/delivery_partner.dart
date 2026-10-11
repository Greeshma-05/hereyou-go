class DeliveryPartner {
  const DeliveryPartner({
    this.name = 'Demo Delivery Partner',
    this.email = 'partner@routerescue.demo',
    this.isOnline = false,
    this.notificationsEnabled = true,
    this.hapticsEnabled = true,
  });
  final bool isOnline;
  final bool notificationsEnabled;
  final bool hapticsEnabled;
  final String name;
  final String email;
  double get demoRating => 4.9;
  DeliveryPartner copyWith({
    bool? isOnline,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
  }) => DeliveryPartner(
    name: name,
    email: email,
    isOnline: isOnline ?? this.isOnline,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
  );
}
