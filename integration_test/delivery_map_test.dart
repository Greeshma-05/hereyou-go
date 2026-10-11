import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/providers/order_provider.dart';
import 'package:route_rescue/screens/orders/order_detail_screen.dart';
import '../test/state_test.dart' show sampleJourney;
import '../test/support/demo_flow.dart' show tapVisible;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android delivery map calculates a road route between public sample points',
    (tester) async {
      await tester.pumpWidget(const RouteRescueApp());
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Get Started'));
      await tapVisible(tester, find.text('Continue as guest'));
      final context = tester.element(find.byTooltip('Open cart'));
      final orders = context.read<OrderProvider>();
      final order = await orders.place([
        CartItem(Catalog.product('meal'), 1),
      ], sampleJourney());
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailScreen(reference: order.reference),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('View delivery map'));
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Courier tracking not connected'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
      await binding.convertFlutterSurfaceToImage();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('here-you-go-delivery-map');

      // Only the fixed fictional shop and public KSRTC bus stand from mock data
      // are sent to routing.openstreetmap.de; no real user location is used.
      await tester.drag(find.text('Order placed'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Show road route'));
      await tapVisible(tester, find.text('Calculate route'));
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.textContaining('Drive estimate ·'), findsOneWidget);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .first
            .points
            .length,
        greaterThan(3),
      );
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(
        markers.any((m) => m.key == const ValueKey('delivery-courier-pin')),
        isFalse,
      );
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      scroll.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.drag(find.text('Order placed'), const Offset(0, 220));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('here-you-go-delivery-map-road-route');
      expect(tester.takeException(), isNull);
    },
  );
}
