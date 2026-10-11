import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/firebase/catalog_serialization.dart';
import 'package:route_rescue/data/firebase/firebase_user_repository.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/models/order_model.dart';
import 'package:route_rescue/services/location_service.dart';
import 'package:routerescue_partner/live/delivery_app.dart';
import 'package:here_you_go_vendor/screens/orders_screen.dart';

class FixedLocation extends LocationService {
  @override
  Future<LocationResult> current() async => LocationResult(
    LocationState.ready,
    'Test location',
    position: const LatLng(9.9772, 76.289),
    accuracyMeters: 10,
    capturedAt: DateTime.now(),
  );
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var n = 0; n < 100 && !ready(); n++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<FirebaseApp> client(String name) async {
  final app = await Firebase.initializeApp(
    name: name,
    options: const FirebaseOptions(
      apiKey: 'AIzaSy000000000000000000000000000000000',
      appId: '1:1234567890:android:local',
      projectId: 'demo-route-rescue',
      messagingSenderId: '1234567890',
    ),
  );
  await FirebaseAuth.instanceFor(app: app).useAuthEmulator('10.0.2.2', 9199);
  final db = FirebaseFirestore.instanceFor(app: app);
  db.settings = const Settings(persistenceEnabled: false);
  db.useFirestoreEmulator('10.0.2.2', 8180);
  return app;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native three-app order flow, live partner screens and verified handover',
    (tester) async {
      expect(
        const bool.fromEnvironment('FIREBASE_USE_EMULATORS'),
        isTrue,
        reason: 'This test must never use production.',
      );
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final customer = await client('customer-$suffix'),
          vendor = await client('vendor-$suffix'),
          partner = await client('partner-$suffix');
      final customerAuth = FirebaseAuth.instanceFor(app: customer),
          vendorAuth = FirebaseAuth.instanceFor(app: vendor),
          partnerAuth = FirebaseAuth.instanceFor(app: partner);
      final customerDb = FirebaseFirestore.instanceFor(app: customer),
          vendorDb = FirebaseFirestore.instanceFor(app: vendor),
          partnerDb = FirebaseFirestore.instanceFor(app: partner);
      final customerRepository = FirebaseUserRepository(
        auth: customerAuth,
        firestore: customerDb,
      );
      final vendorRepository = FulfillmentRepository.forApp(vendor),
          partnerRepository = FulfillmentRepository.forApp(partner);
      await customerRepository.signUp(
        'Traveler',
        'customer-$suffix@example.test',
        'Local-test-password-42',
      );
      await vendorAuth.createUserWithEmailAndPassword(
        email: 'vendor-$suffix@example.test',
        password: 'Local-test-password-42',
      );
      final uid = vendorAuth.currentUser!.uid;
      final now = FieldValue.serverTimestamp();
      final batch = vendorDb.batch();
      batch.set(vendorDb.doc('vendorAccounts/$uid'), {
        'ownerName': 'Test Shop Owner',
        'email': vendorAuth.currentUser!.email,
        'phone': '+919876543210',
        'licenseNumber': '',
        'createdAt': now,
        'updatedAt': now,
      });
      batch.set(vendorDb.doc('vendors/$uid'), {
        'schemaVersion': 1,
        'ownerUid': uid,
        'name': 'Journey Essentials',
        'category': 'food',
        'address': 'MG Road, Kochi',
        'latitude': 9.9772,
        'longitude': 76.289,
        'description': 'Travel essentials',
        'preparationMinutes': 10,
        'isOpen': true,
        'isPublished': true,
        'createdAt': now,
        'updatedAt': now,
      });
      await batch.commit();
      final productData = <String, dynamic>{
        'schemaVersion': 1,
        'vendorId': uid,
        'name': 'Drinking water',
        'category': 'food',
        'pricePaise': 2000,
        'stock': 10,
        'unit': 'Bottle',
        'description': 'Sealed drinking water',
        'strength': '',
        'dosageForm': '',
        'genericName': '',
        'brand': '',
        'manufacturer': '',
        'expiryDate': '',
        'prescriptionRequired': false,
        'isPublished': true,
        'createdAt': now,
        'updatedAt': now,
      };
      await vendorDb.doc('vendors/$uid/products/water').set(productData);
      final requested = RescueOrder(
        reference: 'HYG-native-$suffix',
        createdAt: DateTime.now(),
        vendorId: uid,
        vendorName: 'Journey Essentials',
        journey: Journey(
          mode: JourneyMode.bus,
          operatorName: 'KSRTC',
          boarding: 'Kochi',
          destination: 'Thrissur',
          departure: DateTime.now().add(const Duration(hours: 2)),
          pickup: const PickupStop(
            'custom-bus',
            'KSRTC bus stand, Kochi',
            LatLng(9.98, 76.29),
            'Meet beside the main entrance.',
          ),
        ),
        items: [
          CartItem(
            CatalogSerialization.readProduct(uid, 'water', productData),
            2,
          ),
        ],
        deliveryFeePaise: 2500,
        platformFeePaise: 500,
        verificationCode: '0000',
      );
      final order = await customerRepository.placeLiveOrder(requested);
      expect(order.isPreview, isFalse);
      expect(order.verificationCode, isNot('0000'));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: VendorOrdersScreen(repository: vendorRepository, uid: uid),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Accept order').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('Accept order'));
      await waitFor(
        tester,
        () => find.text('Start preparing').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('Start preparing'));
      await waitFor(
        tester,
        () => find.text('Mark ready for pickup').evaluate().isNotEmpty,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('vendor-live-order');
      await tester.pumpWidget(
        DeliveryApp(
          auth: partnerAuth,
          repository: partnerRepository,
          localTesting: true,
          locationService: FixedLocation(),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Welcome back').evaluate().isNotEmpty,
      );
      await binding.takeScreenshot('delivery-live-login');
      await partnerAuth.createUserWithEmailAndPassword(
        email: 'partner-$suffix@example.test',
        password: 'Local-test-password-42',
      );
      await waitFor(
        tester,
        () => find.text('Save partner profile').evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Asha Partner',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone number'),
        '+919876543210',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save partner profile'));
      await waitFor(
        tester,
        () => find.byType(SwitchListTile).evaluate().isNotEmpty,
      );
      final profileRef = partnerDb.doc(
        'couriers/${partnerAuth.currentUser!.uid}',
      );
      final createdProfile = (await profileRef.get(
        const GetOptions(source: Source.server),
      )).data()!;
      expect(createdProfile['name'], 'Asha Partner');
      expect(createdProfile['online'], false);
      expect(createdProfile['activeOrderId'], isNull);
      await tap(tester, find.text('Profile'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Asha Updated',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(tester, find.text('Save partner profile'));
      await waitFor(tester, () => find.text('Saving…').evaluate().isEmpty);
      final updatedProfile = (await profileRef.get(
        const GetOptions(source: Source.server),
      )).data()!;
      expect(updatedProfile['name'], 'Asha Updated');
      expect(updatedProfile['createdAt'], createdProfile['createdAt']);
      expect(find.textContaining('Your profile could not sync'), findsNothing);
      await binding.takeScreenshot('delivery-profile-saved');
      await tap(tester, find.text('Nearby'));
      await tap(tester, find.byType(SwitchListTile));
      await waitFor(
        tester,
        () => find.text('Accept delivery').evaluate().isNotEmpty,
      );
      await binding.takeScreenshot('delivery-nearby-orders');
      // Show the vendor UI while the independent partner SDK session stays
      // available, as it would on the delivery partner's separate device.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: VendorOrdersScreen(repository: vendorRepository, uid: uid),
        ),
      );
      await profileRef
          .snapshots()
          .firstWhere((doc) => doc.data()?['online'] == false)
          .timeout(const Duration(seconds: 20));
      await waitFor(
        tester,
        () => find.text('Assign delivery partner').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('Assign delivery partner'));
      await waitFor(
        tester,
        () => find.text('No available partners nearby').evaluate().isNotEmpty,
      );
      // The partner comes online AFTER the vendor opened the empty list.
      // The vendor must discover them without pressing refresh or reopening.
      await partnerRepository.call('presence', {
        'online': true,
        'location': {
          'latitude': 9.9772,
          'longitude': 76.289,
          'accuracy': 10,
          'recordedAt': DateTime.now().millisecondsSinceEpoch,
        },
      });
      await waitFor(
        tester,
        () => find.text('Assign Asha Updated').evaluate().isNotEmpty,
      );
      await binding.takeScreenshot('vendor-nearby-partners');
      await tap(tester, find.text('Assign Asha Updated'));
      await waitFor(
        tester,
        () => find.text('Partner: Asha Updated').evaluate().isNotEmpty,
      );
      expect(find.text('Assign delivery partner'), findsNothing);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('vendor-assigned-order');
      await tester.pumpWidget(
        DeliveryApp(
          auth: partnerAuth,
          repository: partnerRepository,
          localTesting: true,
          locationService: FixedLocation(),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Open active delivery').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('Open active delivery'));
      await waitFor(
        tester,
        () => find.text('Navigate to shop').evaluate().isNotEmpty,
      );
      final assigned =
          (await customerDb
                  .doc(
                    'users/${customerAuth.currentUser!.uid}/orders/${order.reference}',
                  )
                  .get())
              .data()!;
      expect(assigned['courierName'], 'Asha Updated');
      expect(assigned['assignmentSource'], 'vendor');
      expect(assigned['courierId'], partnerAuth.currentUser!.uid);
      await vendorRepository.transition(order.reference, 'ready');
      await waitFor(
        tester,
        () => find.text('Confirm pickup').evaluate().isNotEmpty,
      );
      await binding.takeScreenshot('delivery-active-order');
      await tap(tester, find.text('Confirm pickup'));
      await waitFor(
        tester,
        () => find.text('Verify handover').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('Verify handover'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Customer’s four-digit code'),
        order.verificationCode,
      );
      await tap(tester, find.text('Verify & finish'));
      await waitFor(
        tester,
        () => find.text('No active delivery').evaluate().isNotEmpty,
      );
      expect(
        (await customerDb
                .doc(
                  'users/${customerAuth.currentUser!.uid}/orders/${order.reference}',
                )
                .get())
            .data()!['status'],
        'handedOver',
      );
      expect(
        (await partnerDb.doc('couriers/${partnerAuth.currentUser!.uid}').get())
            .data()!['activeOrderId'],
        isNull,
      );
      await tap(tester, find.text('History'));
      await waitFor(
        tester,
        () => find.text('1 completed deliveries').evaluate().isNotEmpty,
      );
      await binding.takeScreenshot('delivery-completed-history');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(seconds: 1));
      for (final auth in [customerAuth, vendorAuth, partnerAuth]) {
        await auth.signOut();
      }
      for (final app in [customer, vendor, partner]) {
        await app.delete();
      }
    },
  );
}
