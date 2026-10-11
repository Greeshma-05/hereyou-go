/// Only trusted build configuration chooses where Firebase ID tokens are sent.
/// Never accept this address from an order, deep link or user input.
Uri? fulfillmentEndpoint(String value, {bool allowLocalHttp = false}) {
  if (value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  const localHosts = {'localhost', '127.0.0.1', '10.0.2.2', '::1'};
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path != '/fulfillment' ||
      (uri.scheme != 'https' &&
          !(allowLocalHttp &&
              uri.scheme == 'http' &&
              localHosts.contains(uri.host)))) {
    throw StateError(
      'Configure FULFILLMENT_URL with the secure /fulfillment address of the order service.',
    );
  }
  return uri;
}
