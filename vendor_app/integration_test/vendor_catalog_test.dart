import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:here_you_go_vendor/main.dart' as vendor_main;
import 'package:route_rescue/app.dart';
import 'package:route_rescue/data/firebase/firebase_catalog_repository.dart';
import 'package:route_rescue/providers/catalog_provider.dart';
import 'package:route_rescue/widgets/product_card.dart';
import 'package:here_you_go_vendor/state/merchant_state.dart';
import 'package:route_rescue/models/category.dart';

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final f = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(f);
  await tester.enterText(f, value);
  await tester.pump();
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var n = 0; n < 80 && !ready(); n++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
  }
  expect(ready(), true);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'vendor registration and medicine stock sync to a separate guest customer',
    (tester) async {
      expect(
        const bool.fromEnvironment('FIREBASE_USE_EMULATORS'),
        true,
        reason: 'This test must never run against production.',
      );
      await vendor_main.main();
      await FirebaseAuth.instanceFor(
        app: Firebase.app('vendor-local'),
      ).signOut();
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.text('Create vendor account').evaluate().isNotEmpty,
      );
      await fill(
        tester,
        'Email address',
        'vendor-${DateTime.now().microsecondsSinceEpoch}@example.test',
      );
      await fill(tester, 'Password', 'Local-test-password-42');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Create vendor account'));
      await waitFor(
        tester,
        () => find.text('Register your shop').evaluate().isNotEmpty,
      );
      await fill(tester, 'Shop name', 'Integration pharmacy');
      await tap(tester, find.byType(DropdownButtonFormField<Category>).first);
      await tap(tester, find.text('Medical shop').last);
      await fill(tester, 'Shop address', 'Public integration test entrance');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Pin shop location'));
      final mapFinder = find.byKey(const ValueKey('delivery-location-map'));
      final map = tester.widget<FlutterMap>(mapFinder);
      map.mapController!.move(const LatLng(9.92, 76.29), 16);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(mapFinder));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Use this location'));
      await fill(tester, 'About your shop', 'Local integration test catalog');
      await fill(tester, 'Owner name', 'Test Owner');
      await fill(tester, 'Business phone', '+919876543210');
      await fill(tester, 'Pharmacy license number', 'TEST-ONLY-LICENSE');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save shop'));
      await waitFor(
        tester,
        () => find.text('Add product').evaluate().isNotEmpty,
      );
      final merchant = tester
          .element(find.text('Add product'))
          .read<MerchantState>();
      await tap(tester, find.text('Add product'));
      await fill(tester, 'Medicine name', 'Integration label tablet');
      await fill(tester, 'Strength / concentration', '10 mg');
      await fill(tester, 'Dosage form', 'Tablet');
      await fill(tester, 'Pack size / unit', 'Strip of 10');
      await fill(tester, 'Manufacturer', 'Test manufacturer');
      await fill(tester, 'Expiry date (YYYY-MM-DD)', '2030-12-31');
      await fill(tester, 'Price (₹)', '12.50');
      await fill(tester, 'Available stock', '8');
      await fill(
        tester,
        'Description',
        'Label information for integration testing',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save product'));
      await waitFor(
        tester,
        () =>
            merchant.products.isNotEmpty &&
            find.text('Your shop').evaluate().isNotEmpty,
      );
      expect(merchant.products.single.strength, '10 mg');
      expect(merchant.products.single.pricePaise, 1250);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('vendor-inventory');

      final vendorUid = merchant.uid;
      final productId = merchant.products.single.id.split('/').last;
      final ownerApp = Firebase.app('vendor-local');
      final ownerDb = FirebaseFirestore.instanceFor(app: ownerApp);
      final guestApp = await Firebase.initializeApp(
        name: 'guest-catalog-local',
        options: const FirebaseOptions(
          apiKey: 'local-emulator-key',
          appId: '1:1234567890:android:customerlocal',
          projectId: 'demo-route-rescue',
          messagingSenderId: '1234567890',
        ),
      );
      final guestAuth = FirebaseAuth.instanceFor(app: guestApp);
      await guestAuth.useAuthEmulator('10.0.2.2', 9099);
      expect(guestAuth.currentUser, isNull);
      final guestDb = FirebaseFirestore.instanceFor(app: guestApp);
      guestDb.settings = const Settings(persistenceEnabled: false);
      guestDb.useFirestoreEmulator('10.0.2.2', 8080);
      await tester.pumpWidget(
        RouteRescueApp(catalogRepository: FirebaseCatalogRepository(guestDb)),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Get Started'));
      await tap(tester, find.text('Continue as guest'));
      await tap(tester, find.byTooltip('Explore'));
      final catalog = tester
          .element(find.text('Explore').first)
          .read<CatalogProvider>();
      await waitFor(
        tester,
        () => catalog.products.any((p) => p.id == '$vendorUid/$productId'),
      );
      final search = find.widgetWithText(
        TextField,
        'Search medicine, food, essentials…',
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Integration label');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.text('10 mg · Tablet'), findsOneWidget);
      await tester.ensureVisible(find.byType(ProductCard));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('customer-vendor-catalog');
      final ref = ownerDb
          .collection('vendors')
          .doc(vendorUid)
          .collection('products')
          .doc(productId);
      await ref.update({
        'stock': 0,
        'pricePaise': 1500,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await waitFor(tester, () => catalog.products.single.stock == 0);
      expect(catalog.products.single.pricePaise, 1500);
      expect(find.text('Out of stock'), findsOneWidget);
      await ref.update({
        'isPublished': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await waitFor(tester, () => catalog.products.isEmpty);
      expect(find.byType(ProductCard), findsNothing);
      await ownerDb.collection('vendors').doc(vendorUid).update({
        'isPublished': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await waitFor(tester, () => catalog.vendors.isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await FirebaseAuth.instanceFor(app: ownerApp).signOut();
      await guestApp.delete();
    },
  );
}
