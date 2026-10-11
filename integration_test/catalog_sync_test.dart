import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/app.dart';
import 'package:route_rescue/data/firebase/firebase_catalog_repository.dart';
import 'package:route_rescue/data/firebase/firebase_merchant_repository.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'package:route_rescue/data/mock_journeys.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/models/product_model.dart';
import 'package:route_rescue/models/vendor_model.dart';
import 'package:route_rescue/providers/catalog_provider.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/widgets/product_card.dart';
import 'package:route_rescue/widgets/vendor_card.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var n = 0; n < 100 && !ready(); n++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }
  expect(ready(), isTrue);
  // A server acknowledgement can arrive before the next Flutter frame.
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'new vendor data reaches an already-open customer app and follows the location radius',
    (tester) async {
      expect(
        const bool.fromEnvironment('FIREBASE_USE_EMULATORS'),
        isTrue,
        reason: 'This test may only write to the local test database.',
      );
      Future<FirebaseApp> localApp(String name) => Firebase.initializeApp(
        name: name,
        options: const FirebaseOptions(
          apiKey: 'local-emulator-key',
          appId: '1:1234567890:android:sync',
          projectId: 'demo-route-rescue',
          messagingSenderId: '1234567890',
        ),
      );
      final ownerApp = await localApp('sync-vendor-local');
      final customerApp = await localApp('sync-customer-local');
      final ownerAuth = FirebaseAuth.instanceFor(app: ownerApp);
      final customerAuth = FirebaseAuth.instanceFor(app: customerApp);
      await ownerAuth.useAuthEmulator('10.0.2.2', 9099);
      await customerAuth.useAuthEmulator('10.0.2.2', 9099);
      await customerAuth.signOut();
      final ownerDb = FirebaseFirestore.instanceFor(app: ownerApp);
      final customerDb = FirebaseFirestore.instanceFor(app: customerApp);
      for (final db in [ownerDb, customerDb]) {
        db.settings = const Settings(persistenceEnabled: false);
        db.useFirestoreEmulator('10.0.2.2', 8080);
      }
      final repo = FirebaseMerchantRepository(
        auth: ownerAuth,
        firestore: ownerDb,
      );
      final email =
          'sync-${DateTime.now().microsecondsSinceEpoch}@example.test';
      await repo.signUp(email, 'Local-sync-password-42');
      final uid = ownerAuth.currentUser!.uid;
      final productName = 'Sync tablet $uid';
      final account = MerchantAccount(
        ownerName: 'Sync test owner',
        email: email,
        phone: '+919876543210',
        licenseNumber: 'TEST-ONLY-LICENSE',
      );
      Vendor shop(LatLng position, {bool published = true}) => Vendor(
        id: uid,
        name: 'Live sync pharmacy',
        category: Category.medicine,
        position: position,
        area: 'Fixed local test coordinate',
        preparationMinutes: 10,
        rating: 0,
        description: 'Local integration test',
        isSample: false,
        published: published,
      );
      Product product({
        String id = '',
        int stock = 8,
        int price = 1250,
        bool published = true,
      }) => Product(
        id: id,
        vendorId: uid,
        name: productName,
        category: Category.medicine,
        pricePaise: price,
        stock: stock,
        unit: 'Strip of 10',
        description: 'Label information only',
        strength: '10 mg',
        dosageForm: 'Tablet',
        manufacturer: 'Test manufacturer',
        expiryDate: '2035-12-31',
        prescriptionRequired: true,
        published: published,
      );
      try {
        await tester.pumpWidget(
          RouteRescueApp(
            catalogRepository: FirebaseCatalogRepository(customerDb),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, find.text('Get Started'));
        await tap(tester, find.text('Continue as guest'));
        await tap(tester, find.byTooltip('Explore'));
        final context = tester.element(
          find.byKey(const ValueKey('shop-search-center')),
        );
        final catalog = context.read<CatalogProvider>();
        final journey = context.read<JourneyProvider>();
        await waitFor(tester, () => !catalog.loading);

        // The customer is listening before a vendor publishes anything.
        await repo.saveShop(shop(kochiCenter), account, creating: true);
        await waitFor(tester, () => catalog.vendor(uid) != null);
        await repo.saveProduct(uid, product(), creating: true);
        await waitFor(
          tester,
          () => catalog.products.any((p) => p.vendorId == uid),
        );
        final id = catalog.products.firstWhere((p) => p.vendorId == uid).id;
        expect(find.byKey(ValueKey('vendor-$uid')), findsOneWidget);
        expect(
          tester
              .widget<MarkerLayer>(find.byType(MarkerLayer))
              .markers
              .any((m) => m.key == ValueKey('map-vendor-$uid')),
          isTrue,
        );
        final search = find.widgetWithText(
          TextField,
          'Search medicine, food, essentials…',
        );
        await tester.ensureVisible(search);
        await tester.enterText(search, productName);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.byType(ProductCard), findsOneWidget);

        await repo.saveProduct(
          uid,
          product(id: id, stock: 0, price: 1600),
          creating: false,
        );
        await waitFor(tester, () => catalog.product(id)?.stock == 0);
        expect(catalog.product(id)?.pricePaise, 1600);
        expect(find.text('Out of stock'), findsOneWidget);

        const distance = Distance(roundResult: false);
        await repo.saveShop(
          shop(distance.offset(kochiCenter, 8000, 0)),
          account,
          creating: false,
        );
        await waitFor(
          tester,
          () =>
              catalog.vendor(uid) != null &&
              distance(kochiCenter, catalog.vendor(uid)!.position) > 7900,
        );
        expect(find.byType(ProductCard), findsNothing);
        expect(find.byKey(ValueKey('vendor-$uid')), findsNothing);
        journey.setSearchMode(JourneyMode.train);
        await tester.pumpAndSettle();
        expect(find.byType(ProductCard), findsOneWidget);

        await repo.saveShop(
          shop(distance.offset(kochiCenter, 25000, 0)),
          account,
          creating: false,
        );
        await waitFor(tester, () => catalog.vendor(uid) == null);
        expect(find.byType(ProductCard), findsNothing);
        await repo.saveShop(shop(kochiCenter), account, creating: false);
        await waitFor(tester, () => catalog.product(id) != null);
        await repo.saveProduct(
          uid,
          product(id: id, published: false),
          creating: false,
        );
        await waitFor(tester, () => catalog.product(id) == null);
        await repo.saveProduct(uid, product(id: id), creating: false);
        await waitFor(tester, () => catalog.product(id)?.stock == 8);
        expect(find.byType(ProductCard), findsOneWidget);
        await binding.convertFlutterSurfaceToImage();
        await Scrollable.ensureVisible(
          tester.element(find.byType(ProductCard)),
          alignment: .1,
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('customer-live-vendor-sync');
        await repo.saveShop(
          shop(kochiCenter, published: false),
          account,
          creating: false,
        );
        await waitFor(tester, () => catalog.vendor(uid) == null);
        expect(find.byType(VendorCard), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await repo.signOut();
        await customerApp.delete();
        await ownerApp.delete();
      }
    },
  );
}
