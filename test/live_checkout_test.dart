import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/courier_tracking_source.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/models/order_model.dart';
import 'package:route_rescue/providers/cart_provider.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'package:route_rescue/screens/checkout/checkout_screen.dart';
import 'package:route_rescue/screens/orders/orders_screen.dart';
import 'package:route_rescue/services/mock_order_service.dart';
import 'firebase_state_test.dart' show MemoryRepository, trip, items;
import 'support/demo_flow.dart' show tapVisible;

class LiveRepository extends MemoryRepository implements LiveOrderRepository {
  final attempts = <String>[];
  bool unavailable = true;
  @override
  CourierTrackingSource get tracking => const UnavailableCourierTracking();
  @override
  Future<void> cancelOrder(String reference) async {}
  @override
  Future<RescueOrder> placeLiveOrder(RescueOrder order) async {
    attempts.add(order.reference);
    if (unavailable) {
      throw StateError('Order service unavailable. Please retry.');
    }
    return RescueOrder(
      reference: order.reference,
      createdAt: order.createdAt,
      vendorId: order.vendorId,
      vendorName: order.vendorName,
      journey: order.journey,
      items: order.items,
      deliveryFeePaise: order.deliveryFeePaise,
      platformFeePaise: order.platformFeePaise,
      verificationCode: '1234',
      isPreview: false,
    );
  }
}

void main() {
  testWidgets(
    'failed live checkout preserves cart and retry sends the same order',
    (tester) async {
      final repo = LiveRepository();
      final orders = OrderProvider(repository: repo, uid: 'alice');
      final cart = CartProvider()..add('meal');
      final journeys = JourneyProvider();
      await journeys.save(trip());
      addTearDown(() async {
        orders.dispose();
        cart.dispose();
        journeys.dispose();
        await repo.auth.close();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: orders),
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider.value(value: journeys),
          ],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const CheckoutScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create preview'), findsNothing);
      await tapVisible(tester, find.text('Place order'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(
        find.text('Order service unavailable. Please retry.'),
        findsOneWidget,
      );
      expect(cart.isEmpty, isFalse);
      expect(orders.orders, isEmpty);
      expect(repo.orderWrites, 0);
      expect(find.text('Order sent to shop'), findsNothing);
      repo.unavailable = false;
      await tapVisible(tester, find.text('Place order'));
      expect(repo.attempts.length, 2);
      expect(repo.attempts[0], repo.attempts[1]);
      expect(cart.isEmpty, isTrue);
      expect(orders.orders.single.isPreview, isFalse);
      expect(find.text('Order sent to shop'), findsOneWidget);
      expect(find.text('Waiting for the shop to accept.'), findsOneWidget);
      expect(find.text('Order confirmed'), findsNothing);
    },
  );

  testWidgets('legacy account previews never appear as active vendor orders', (
    tester,
  ) async {
    final repo = MemoryRepository();
    repo.orders['alice'] = [
      MockOrderService().create(items: items(), journey: trip()),
    ];
    final orders = OrderProvider(repository: repo, uid: 'alice');
    final cart = CartProvider();
    addTearDown(() async {
      orders.dispose();
      cart.dispose();
      await repo.auth.close();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: orders),
          ChangeNotifierProvider.value(value: cart),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Previews'), findsOneWidget);
    expect(find.text('Preview · not sent to shop'), findsOneWidget);
    expect(find.text('Active orders'), findsNothing);
    expect(find.text('On the way'), findsNothing);
  });
}
