import 'package:flutter_test/flutter_test.dart';
import 'package:route_rescue/data/fulfillment_endpoint.dart';

void main() {
  test(
    'only secure explicit order-service URLs can receive sign-in tokens',
    () {
      expect(fulfillmentEndpoint(''), isNull);
      expect(
        fulfillmentEndpoint('https://orders.example.test/fulfillment')!.host,
        'orders.example.test',
      );
      for (final value in [
        'http://orders.example.test/fulfillment',
        'https://user:password@orders.example.test/fulfillment',
        'https://orders.example.test/fulfillment?redirect=elsewhere',
        'https://orders.example.test/fulfillment#fragment',
        'https://orders.example.test',
        'http://127.0.0.1:10000/fulfillment',
      ]) {
        expect(() => fulfillmentEndpoint(value), throwsStateError);
      }
    },
  );
  test('only emulator builds allow local cleartext servers', () {
    expect(
      fulfillmentEndpoint(
        'http://10.0.2.2:10000/fulfillment',
        allowLocalHttp: true,
      ),
      isNotNull,
    );
    expect(
      () => fulfillmentEndpoint(
        'http://external.test/fulfillment',
        allowLocalHttp: true,
      ),
      throwsStateError,
    );
  });
}
