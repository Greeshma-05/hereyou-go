import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_rescue/core/utils/formatters.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/mock_journeys.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/models/order_model.dart';
import 'package:route_rescue/models/product_model.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/providers/location_provider.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'package:route_rescue/providers/preferences_provider.dart';
import 'package:route_rescue/providers/session_provider.dart';
import 'package:route_rescue/services/location_service.dart';
import 'package:route_rescue/services/mock_order_service.dart';

Journey sampleJourney({DateTime? departure, PickupStop? pickup}) => Journey(
  mode: JourneyMode.bus,
  operatorName: 'Sample bus',
  boarding: 'Kochi',
  destination: 'Thrissur',
  departure: departure ?? DateTime.now().add(const Duration(hours: 2)),
  pickup: pickup ?? busStops.first,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cart calculates in paise, includes configurable fees, and removes zero quantities',
    () {
      final cart = CartProvider();
      expect(cart.totalPaise, 0);
      cart.add('meal');
      cart.add('meal');
      cart.add('water');
      expect(cart.count, 3);
      expect(cart.subtotalPaise, 30000);
      expect(cart.deliveryFeePaise, 2500);
      expect(cart.platformFeePaise, 500);
      expect(cart.totalPaise, 33000);
      cart.decrease('meal');
      expect(cart.subtotalPaise, 16000);
      cart.remove('meal');
      cart.decrease('water');
      expect(cart.isEmpty, isTrue);
      expect(cart.totalPaise, 0);
    },
  );
  test(
    'cart refuses mixed vendors, closed vendors, unavailable and excess stock',
    () {
      final cart = CartProvider();
      cart.add('water');
      expect(cart.add('pads'), AddResult.differentVendor);
      expect(cart.vendorId, 'cafe');
      expect(cart.count, 1);
      expect(cart.add('pillow'), AddResult.unavailable);
      expect(cart.add('saline'), AddResult.outOfStock);
      for (var i = 1; i < Catalog.product('water').stock; i++) {
        cart.add('water');
      }
      expect(cart.add('water'), AddResult.outOfStock);
      expect(cart.quantity('water'), 20);
    },
  );
  test(
    'local search finds vendors, products, strength and dosage form with category filters',
    () {
      expect(Catalog.searchProducts('KITCHEN', null).length, 4);
      expect(Catalog.searchVendors('diapers', null).single.id, 'baby');
      expect(
        Catalog.searchProducts('0.65%', Category.medicine).single.id,
        'saline',
      );
      expect(
        Catalog.searchProducts('nasal spray', Category.medicine).single.id,
        'saline',
      );
      expect(Catalog.searchProducts('water', Category.hygiene), isEmpty);
      expect(Catalog.searchVendors('not-a-shop', null), isEmpty);
    },
  );
  test('journey validates required fields', () {
    final provider = JourneyProvider();
    expect(
      () => provider.save(
        Journey(
          mode: JourneyMode.bus,
          operatorName: '',
          boarding: 'Kochi',
          destination: 'Kochi',
          departure: DateTime.now(),
          pickup: busStops.first,
        ),
      ),
      throwsArgumentError,
    );
    provider.save(sampleJourney());
    expect(provider.journey!.pickup.id, 'ksrtc');
    provider.clear();
    expect(provider.journey, isNull);
  });
  test(
    'checkout rejects absent journey, empty cart, stale departure and wrong pickup mode',
    () {
      final service = MockOrderService();
      final items = [CartItem(Catalog.product('water'), 1)];
      expect(
        () => service.create(items: items, journey: null),
        throwsStateError,
      );
      expect(
        () => service.create(items: [], journey: sampleJourney()),
        throwsStateError,
      );
      expect(
        () => service.create(
          items: items,
          journey: sampleJourney(
            departure: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        ),
        throwsStateError,
      );
      expect(
        () => service.create(
          items: items,
          journey: sampleJourney(pickup: trainStops.first),
        ),
        throwsStateError,
      );
      expect(
        () => service.create(
          items: [CartItem(Catalog.product('water'), 21)],
          journey: sampleJourney(),
        ),
        throwsStateError,
      );
      expect(
        () => service.create(
          items: [CartItem(Catalog.product('pillow'), 1)],
          journey: sampleJourney(),
        ),
        throwsStateError,
      );
      expect(
        () => service.create(
          items: [...items, ...items],
          journey: sampleJourney(),
        ),
        throwsStateError,
      );
      expect(
        () => service.create(
          items: [...items, CartItem(Catalog.product('pads'), 1)],
          journey: sampleJourney(),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'order uses canonical catalog pricing and keeps an immutable snapshot',
    () {
      const forged = Product(
        id: 'water',
        vendorId: 'cafe',
        name: 'Tampered',
        category: Category.food,
        pricePaise: 1,
        stock: 999,
        unit: '',
        description: '',
      );
      final original = [const CartItem(forged, 2)];
      final order = MockOrderService().create(
        items: original,
        journey: sampleJourney(),
      );
      original.clear();
      expect(order.items.length, 1);
      expect(order.subtotalPaise, 4000);
      expect(order.totalPaise, 7000);
      expect(() => order.items.clear(), throwsUnsupportedError);
    },
  );
  test(
    'order progresses only through explicit actions and stops at handed over',
    () async {
      final provider = OrderProvider();
      final cart = CartProvider()..add('meal');
      final first = await provider.place(cart.items, sampleJourney());
      final second = await provider.place(cart.items, sampleJourney());
      expect(first.reference, isNot(second.reference));
      expect(first.verificationCode, matches(RegExp(r'^\d{4}$')));
      cart.clear();
      expect(first.items.single.quantity, 1);
      for (var i = 1; i < OrderStatus.previewStages.length; i++) {
        provider.advance(first.reference);
        expect(
          provider.byReference(first.reference).status,
          OrderStatus.previewStages[i],
        );
      }
      provider.advance(first.reference);
      expect(
        provider.byReference(first.reference).status,
        OrderStatus.handedOver,
      );
      expect(provider.byReference(second.reference).status, OrderStatus.placed);
      expect(first.status, OrderStatus.placed);
    },
  );
  test('only non-sensitive preferences survive provider recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final prefs = PreferencesProvider(storage);
    await prefs.toggle('Drinking water');
    await prefs.setNotifications(true);
    final restored = PreferencesProvider(storage);
    expect(restored.checked('Drinking water'), isTrue);
    expect(restored.notifications, isTrue);
    expect(storage.getKeys(), {'checklist', 'notifications'});
    final session = SessionProvider()..enterDemo(name: 'Demo');
    session.logout();
    expect(session.customer, isNull);
  });
  test('preference failure preserves usable session state', () async {
    final prefs = PreferencesProvider(null);
    await prefs.setNotifications(true);
    expect(prefs.notifications, isTrue);
    expect(prefs.error, isNotNull);
  });
  for (final state in [
    LocationState.denied,
    LocationState.deniedForever,
    LocationState.disabled,
    LocationState.error,
  ]) {
    test(
      'location $state remains recoverable without fabricated GPS',
      () async {
        final provider = LocationProvider(service: _FakeLocationService(state));
        await provider.locate();
        expect(provider.result.state, state);
        expect(provider.position, isNull);
        provider.clear();
        expect(provider.result.state, LocationState.idle);
      },
    );
  }
  test('INR and contact formatting are appropriate for local forms', () {
    expect(money(19900), '₹199');
    expect(money(12345600), '₹1,23,456');
    expect(money(2250), '₹22.50');
    expect(contactError('demo@example.com'), isNull);
    expect(contactError('9876543210'), isNull);
    expect(contactError('invalid'), isNotNull);
  });
}

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.state);
  final LocationState state;
  @override
  Future<LocationResult> current() async =>
      LocationResult(state, 'Manual pickup is available.');
}
