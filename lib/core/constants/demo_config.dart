class DemoConfig {
  static const deliveryFeePaise = 2500;
  static const platformFeePaise = 500;
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const routingUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-car',
  );
  static const healthcareNotice =
      'Preview pharmacy inventory — stock is unverified. No medical advice, '
      'medicine recommendations or substitutions. Real fulfillment requires '
      'a licensed pharmacy and all applicable safeguards.';
}
