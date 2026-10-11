import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/firebase/cloud_serialization.dart';
import 'package:route_rescue/data/mock_journeys.dart';
import 'package:route_rescue/data/user_repository.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/models/order_model.dart';
import 'package:route_rescue/models/user_model.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'package:route_rescue/providers/preferences_provider.dart';
import 'package:route_rescue/providers/session_provider.dart';
import 'package:route_rescue/screens/main_shell.dart';
import 'package:route_rescue/services/mock_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Journey trip() => Journey(
  mode: JourneyMode.bus,
  operatorName: 'KSRTC 101',
  boarding: 'Kochi',
  destination: 'Thrissur',
  departure: DateTime.now().add(const Duration(hours: 3)),
  pickup: busStops.first,
);
List<CartItem> items() => [CartItem(Catalog.product('meal'), 2)];
Future<void> tick() => Future<void>.delayed(Duration.zero);

class MemoryRepository implements UserRepository {
  final auth = StreamController<Customer?>.broadcast();
  final orders = <String, List<RescueOrder>>{};
  final journeys = <String, List<SavedJourney>>{};
  final preferences = <String, SavedPreferences>{};
  Object? writeError;
  Object? authError;
  Completer<void>? orderGate;
  int orderWrites = 0;
  @override
  Stream<Customer?> get authChanges => auth.stream;
  @override
  Future<void> signIn(String email, String password) async {
    if (authError != null) throw authError!;
    auth.add(Customer(uid: 'alice', name: 'Alice', contact: email));
  }

  @override
  Future<void> signUp(String name, String email, String password) =>
      signIn(email, password);
  @override
  Future<void> signOut() async => auth.add(null);
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> updateProfile(String name) async {}
  @override
  Stream<List<RescueOrder>> watchOrders(String uid) =>
      Stream.value(List.of(orders[uid] ?? []));
  @override
  Stream<List<SavedJourney>> watchJourneys(String uid) =>
      Stream.value(List.of(journeys[uid] ?? []));
  @override
  Stream<SavedPreferences> watchPreferences(String uid) =>
      Stream.value(preferences[uid] ?? const SavedPreferences());
  @override
  Future<void> saveOrder(String uid, RescueOrder order) async {
    orderWrites++;
    if (orderGate != null) await orderGate!.future;
    if (writeError != null) throw writeError!;
    orders.putIfAbsent(uid, () => []).insert(0, order);
  }

  @override
  Future<void> saveJourney(String uid, SavedJourney journey) async {
    if (writeError != null) throw writeError!;
    journeys.putIfAbsent(uid, () => []).insert(0, journey);
  }

  @override
  Future<void> savePreferences(String uid, SavedPreferences value) async {
    if (writeError != null) throw writeError!;
    preferences[uid] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Firestore snapshots retain prices, vendor, pickup and pending timestamps',
    () {
      final original = MockOrderService().create(
        items: items(),
        journey: trip(),
      );
      final document = CloudSerialization.order(original);
      document['createdAt'] =
          null; // A pending server timestamp uses clientCreatedAt.
      final restored = CloudSerialization.readOrder(document);
      expect(restored.reference, original.reference);
      expect(restored.vendorName, original.vendorName);
      expect(restored.totalPaise, original.totalPaise);
      expect(restored.createdAt, original.createdAt);
      expect(
        restored.journey.pickup.position,
        original.journey.pickup.position,
      );
      expect(
        restored.items.single.product.name,
        original.items.single.product.name,
      );
      expect(restored.items.single.quantity, 2);
      expect(() => restored.items.clear(), throwsUnsupportedError);
    },
  );
  test(
    'saved order and travel history survive providers being recreated',
    () async {
      final repo = MemoryRepository();
      final orders = OrderProvider(repository: repo, uid: 'alice');
      final journeys = JourneyProvider(repository: repo, uid: 'alice');
      await tick();
      await journeys.save(trip());
      final saved = await orders.place(items(), journeys.journey);
      orders.dispose();
      journeys.dispose();
      final restoredOrders = OrderProvider(repository: repo, uid: 'alice');
      final restoredJourneys = JourneyProvider(repository: repo, uid: 'alice');
      final otherOrders = OrderProvider(repository: repo, uid: 'bob');
      await tick();
      expect(restoredOrders.orders.single.reference, saved.reference);
      expect(restoredJourneys.history.single.journey.destination, 'Thrissur');
      expect(otherOrders.orders, isEmpty);
      restoredOrders.advance(saved.reference);
      expect(restoredOrders.orders.single.status, OrderStatus.placed);
      restoredOrders.dispose();
      restoredJourneys.dispose();
      otherOrders.dispose();
      await repo.auth.close();
    },
  );
  test(
    'failed cloud saves never appear successful and checkout can retry',
    () async {
      final repo = MemoryRepository()..writeError = StateError('offline');
      final orders = OrderProvider(repository: repo, uid: 'alice');
      final journeys = JourneyProvider(repository: repo, uid: 'alice');
      await tick();
      await expectLater(orders.place(items(), trip()), throwsStateError);
      await expectLater(journeys.save(trip()), throwsStateError);
      expect(orders.orders, isEmpty);
      expect(journeys.history, isEmpty);
      repo.writeError = null;
      await orders.place(items(), trip());
      expect(orders.orders, hasLength(1));
      orders.dispose();
      journeys.dispose();
      await repo.auth.close();
    },
  );
  test('repeated checkout taps make one cloud write', () async {
    final repo = MemoryRepository()..orderGate = Completer<void>();
    final orders = OrderProvider(repository: repo, uid: 'alice');
    await tick();
    final first = orders.place(items(), trip());
    final second = orders.place(items(), trip());
    expect(identical(first, second), isTrue);
    expect(repo.orderWrites, 1);
    repo.orderGate!.complete();
    expect((await first).reference, (await second).reference);
    expect(orders.orders, hasLength(1));
    orders.dispose();
    await repo.auth.close();
  });
  test(
    'signed-in preferences ignore device-global guest preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'notifications': true,
        'checklist': ['Drinking water'],
      });
      final storage = await SharedPreferences.getInstance();
      final repo = MemoryRepository();
      final prefs = PreferencesProvider(
        storage,
        repository: repo,
        uid: 'alice',
      );
      await tick();
      expect(prefs.notifications, isFalse);
      expect(prefs.checked('Drinking water'), isFalse);
      await prefs.toggle('Tickets & ID');
      await prefs.setNotifications(true);
      expect(repo.preferences['alice']!.checklist, ['Tickets & ID']);
      expect(storage.getStringList('checklist'), ['Drinking water']);
      prefs.dispose();
      await repo.auth.close();
    },
  );
  test('authentication failures do not create a local account', () async {
    final repo = MemoryRepository()
      ..authError = FirebaseAuthException(code: 'invalid-credential');
    final session = SessionProvider(repository: repo);
    repo.auth.add(null);
    await tick();
    final success = await session.authenticate(
      signup: false,
      name: '',
      email: 'alice@example.test',
      password: 'wrong-password',
    );
    expect(success, isFalse);
    expect(session.customer, isNull);
    expect(session.busy, isFalse);
    expect(session.error, 'The email or password is incorrect.');
    session.dispose();
    await repo.auth.close();
  });
  for (final code in ['unknown', 'internal-error', 'configuration-not-found']) {
    test(
      'missing Firebase setup is explained for $code without signing in',
      () async {
        final repo = MemoryRepository()
          ..authError = FirebaseAuthException(
            code: code,
            message:
                'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]',
          );
        final session = SessionProvider(repository: repo);
        repo.auth.add(null);
        await tick();
        expect(
          await session.authenticate(
            signup: true,
            name: 'Traveler',
            email: 'signup@example.test',
            password: 'Test-password-42',
          ),
          isFalse,
        );
        expect(session.customer, isNull);
        expect(session.busy, isFalse);
        expect(
          session.error,
          'Account sign-in has not been enabled yet. You can continue as a guest.',
        );
        session.dispose();
        await repo.auth.close();
      },
    );
  }
  test('unrecognized internal auth errors keep server details private', () {
    expect(
      SessionProvider.authMessage(
        FirebaseAuthException(
          code: 'unknown',
          message: 'Internal diagnostic details for signup@example.test',
        ),
      ),
      'Could not sign in. Please try again.',
    );
  });
  testWidgets('switching accounts recreates cart and private history', (
    tester,
  ) async {
    final repo = MemoryRepository();
    repo.orders['alice'] = [
      MockOrderService().create(items: items(), journey: trip()),
    ];
    await tester.pumpWidget(RouteRescueApp(repository: repo));
    repo.auth.add(const Customer(uid: 'alice', name: 'Alice'));
    await tester.pumpAndSettle();
    var context = tester.element(find.byType(MainShell));
    context.read<CartProvider>().add('water');
    final oldOrders = context.read<OrderProvider>();
    await tester.pumpAndSettle();
    expect(oldOrders.orders, hasLength(1));
    repo.auth.add(const Customer(uid: 'bob', name: 'Bob'));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(MainShell));
    expect(context.read<CartProvider>().isEmpty, isTrue);
    expect(identical(context.read<OrderProvider>(), oldOrders), isFalse);
    await tester.pumpAndSettle();
    expect(context.read<OrderProvider>().orders, isEmpty);
    expect(tester.takeException(), isNull);
    await repo.auth.close();
  });
}
