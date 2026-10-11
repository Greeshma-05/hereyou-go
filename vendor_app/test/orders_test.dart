import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:here_you_go_vendor/screens/orders_screen.dart';
import 'package:here_you_go_vendor/screens/nearby_partners_screen.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';

Map<String, dynamic> order({
  String reference = 'HYG-1',
  String status = 'placed',
}) => {
  'reference': reference,
  'status': status,
  'vendorId': 'vendor',
  'vendorName': 'Test shop',
  'courierId': null,
  'courierName': null,
  'pickup': {'address': 'Test pickup'},
  'journey': {
    'pickup': {'name': 'Bus stand', 'instructions': 'Main entrance'},
  },
  'items': [
    {
      'quantity': 2,
      'product': {'name': 'Water'},
    },
  ],
  'totalPaise': 7000,
  'deliveryFeePaise': 2500,
};

class OrderApi extends Fake implements FulfillmentRepository {
  final updates = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> partners = [
    {
      'id': 'partner',
      'name': 'Asha',
      'vehicle': 'Motorbike',
      'distanceKm': 1.2,
    },
  ];
  int subscriptions = 0, searches = 0, assignments = 0;
  bool denyFirstWatch = false;
  Object? assignmentError, searchError;
  Completer<void>? gate;
  Completer<void>? searchGate;
  final transitions = <String>[];
  @override
  Stream<List<Map<String, dynamic>>> ordersFor(String field, String uid) {
    expect(field, 'vendorId');
    expect(uid, 'vendor');
    subscriptions++;
    if (denyFirstWatch && subscriptions == 1) {
      return Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
    }
    return watch();
  }

  Stream<List<Map<String, dynamic>>> watch() async* {
    yield orders;
    yield* updates.stream;
  }

  void publish(List<Map<String, dynamic>> value) {
    orders = value;
    updates.add(value);
  }

  @override
  Future<void> transition(
    String reference,
    String status, {
    String? code,
  }) async {
    transitions.add(status);
    publish(
      orders
          .map(
            (o) => o['reference'] == reference ? {...o, 'status': status} : o,
          )
          .toList(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> nearbyCouriers(String reference) async {
    searches++;
    await searchGate?.future;
    if (searchError != null) throw searchError!;
    return partners;
  }

  @override
  Future<void> assignCourier(String reference, String courierId) async {
    assignments++;
    await gate?.future;
    if (assignmentError != null) throw assignmentError!;
    publish(
      orders
          .map(
            (o) => o['reference'] == reference
                ? {...o, 'courierId': courierId, 'courierName': 'Asha'}
                : o,
          )
          .toList(),
    );
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openOrders(WidgetTester tester, OrderApi api) async {
  addTearDown(api.updates.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: VendorOrdersScreen(repository: api, uid: 'vendor'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a new customer order arrives live, is accepted, assigned and moves to history',
    (tester) async {
      final api = OrderApi();
      await openOrders(tester, api);
      expect(find.text('Ready for your first order'), findsOneWidget);
      api.publish([order()]);
      await tester.pumpAndSettle();
      expect(find.text('New (1)'), findsOneWidget);
      expect(find.text('Assign delivery partner'), findsNothing);
      await tap(tester, find.text('Accept order'));
      expect(api.transitions, ['confirmed']);
      expect(find.text('Needs partner (1)'), findsOneWidget);
      await tap(tester, find.text('Assign delivery partner'));
      expect(find.text('Motorbike · 1.2 km from pickup'), findsOneWidget);
      await tap(tester, find.text('Assign Asha'));
      expect(api.assignments, 1);
      expect(find.text('Partner: Asha'), findsOneWidget);
      expect(find.text('Assign delivery partner'), findsNothing);
      expect(api.subscriptions, 1);
      api.publish([
        {...api.orders.single, 'status': 'handedOver'},
      ]);
      await tester.pumpAndSettle();
      await tap(tester, find.text('History (1)'));
      expect(find.text('DELIVERED'), findsOneWidget);
      expect(find.text('Accept order'), findsNothing);
      expect(find.text('Assign delivery partner'), findsNothing);
      expect(api.subscriptions, 1);
    },
  );
  testWidgets('no nearby partners can be refreshed without assigning anyone', (
    tester,
  ) async {
    final api = OrderApi()
      ..orders = [order(status: 'confirmed')]
      ..partners = [];
    await openOrders(tester, api);
    await tap(tester, find.text('Assign delivery partner'));
    expect(find.text('No available partners nearby'), findsOneWidget);
    await tap(tester, find.text('Check again'));
    expect(api.searches, 2);
    expect(api.assignments, 0);
  });
  testWidgets('partners coming online appear without a manual refresh', (
    tester,
  ) async {
    final api = OrderApi()..orders = [order(status: 'confirmed')];
    final available = api.partners;
    api.partners = [];
    await openOrders(tester, api);
    await tap(tester, find.text('Assign delivery partner'));
    expect(find.text('No available partners nearby'), findsOneWidget);

    api.partners = available;
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Assign Asha'), findsOneWidget);
    expect(api.searches, 2);

    api.partners = [];
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Assign Asha'), findsNothing);
    expect(find.text('No available partners nearby'), findsOneWidget);
    await tap(tester, find.byTooltip('Back'));
    final searches = api.searches;
    await tester.pump(const Duration(seconds: 30));
    expect(api.searches, searches);
  });
  testWidgets('returning to the vendor app refreshes partner availability', (
    tester,
  ) async {
    final api = OrderApi()..orders = [order(status: 'confirmed')];
    final available = api.partners;
    api.partners = [];
    await openOrders(tester, api);
    await tap(tester, find.text('Assign delivery partner'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    api.partners = available;
    await tester.pump(const Duration(seconds: 30));
    expect(api.searches, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Assign Asha'), findsOneWidget);
    expect(api.searches, 2);
  });
  testWidgets('slow refreshes do not overlap and can finish after leaving', (
    tester,
  ) async {
    final api = OrderApi()..orders = [order(status: 'confirmed')];
    await openOrders(tester, api);
    await tap(tester, find.text('Assign delivery partner'));
    api.searchGate = Completer<void>();
    await tester.pump(const Duration(seconds: 10));
    expect(api.searches, 2);
    await tester.pump(const Duration(seconds: 30));
    expect(api.searches, 2);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Assign Asha'),
          )
          .onPressed,
      isNull,
    );
    await tap(tester, find.byTooltip('Back'));
    api.searchGate!.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(api.searches, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'an assignment conflict stays visible and offers a fresh search',
    (tester) async {
      final api = OrderApi()
        ..orders = [order(status: 'ready')]
        ..assignmentError = StateError(
          'This partner already has an active delivery.',
        );
      await openOrders(tester, api);
      await tap(tester, find.text('Assign delivery partner'));
      await tap(tester, find.text('Assign Asha'));
      expect(find.byType(NearbyPartnersScreen), findsOneWidget);
      expect(
        find.text('This partner already has an active delivery.'),
        findsOneWidget,
      );
      expect(find.text('Assign Asha'), findsNothing);
      await tap(tester, find.text('Retry nearby partners'));
      expect(api.searches, 2);
      expect(find.text('Assign Asha'), findsOneWidget);
    },
  );
  testWidgets(
    'assignment disables repeated submissions until server confirmation',
    (tester) async {
      final api = OrderApi()
        ..orders = [order(status: 'confirmed')]
        ..gate = Completer<void>();
      await openOrders(tester, api);
      await tap(tester, find.text('Assign delivery partner'));
      await tap(tester, find.text('Assign Asha'));
      expect(find.text('Assigning…'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Assigning…'),
      );
      expect(button.onPressed, isNull);
      expect(api.assignments, 1);
      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Partner: Asha'), findsOneWidget);
    },
  );
  testWidgets('order permission failures have a working retry', (tester) async {
    final api = OrderApi()
      ..denyFirstWatch = true
      ..orders = [order()];
    await openOrders(tester, api);
    expect(find.textContaining('owns this shop'), findsOneWidget);
    await tap(tester, find.text('Retry orders'));
    expect(find.text('Accept order'), findsOneWidget);
    expect(api.subscriptions, 2);
  });
  testWidgets(
    'dashboard new-order count updates without restarting its subscription',
    (tester) async {
      final api = OrderApi();
      addTearDown(api.updates.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VendorOrdersButton(repository: api, uid: 'vendor'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      api.publish([order(), order(reference: 'HYG-2')]);
      await tester.pumpAndSettle();
      expect(find.text('2 new orders to accept'), findsOneWidget);
      api.publish([order(status: 'confirmed'), order(reference: 'HYG-2')]);
      await tester.pumpAndSettle();
      expect(find.text('1 new order to accept'), findsOneWidget);
      expect(api.subscriptions, 1);
    },
  );
  testWidgets('partner search errors and large text fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = OrderApi()
      ..searchError = StateError('The order service is not deployed yet.');
    addTearDown(api.updates.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: NearbyPartnersScreen(
          repository: api,
          order: order(status: 'confirmed'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The order service is not deployed yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
