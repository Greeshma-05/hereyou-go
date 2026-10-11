import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:route_rescue/data/catalog.dart';
import 'package:route_rescue/data/firebase/firebase_user_repository.dart';
import 'package:route_rescue/data/mock_journeys.dart';
import 'package:route_rescue/data/user_repository.dart';
import 'package:route_rescue/firebase_options.dart';
import 'package:route_rescue/models/cart_item_model.dart';
import 'package:route_rescue/models/journey_model.dart';
import 'package:route_rescue/providers/journey_provider.dart';
import 'package:route_rescue/services/mock_order_service.dart';
import 'package:route_rescue/data/firebase/cloud_serialization.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android Firebase signup and history survive a new sign-in', (
    tester,
  ) async {
    // This test must never create an account or order in a production project.
    expect(const bool.fromEnvironment('FIREBASE_USE_EMULATORS'), isTrue);
    expect(DefaultFirebaseOptions.projectId, 'demo-route-rescue');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Testing account storage…'))),
    );
    await tester.runAsync(() async {
      final app = await Firebase.initializeApp(
        name: 'account-integration',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      await auth.useAuthEmulator(host, 9099);
      firestore.useFirestoreEmulator(host, 8080);
      final repository = FirebaseUserRepository(
        auth: auth,
        firestore: firestore,
      );
      final email =
          'android-${DateTime.now().microsecondsSinceEpoch}@example.test';
      const password = 'Local-test-only-42';
      await repository.signUp('Android traveler', email, password);
      final uid = auth.currentUser!.uid;
      final journeys = JourneyProvider(repository: repository, uid: uid);
      await journeys.save(
        Journey(
          mode: JourneyMode.bus,
          operatorName: 'KSRTC 101',
          boarding: 'Kochi',
          destination: 'Thrissur',
          departure: DateTime.now().add(const Duration(hours: 3)),
          pickup: busStops.first,
        ),
      );
      // Keep account-history coverage for existing preview records. The live
      // cross-app checkout is exercised by delivery_app/integration_test.
      final order = MockOrderService().create(
        items: [CartItem(Catalog.product('meal'), 1)],
        journey: journeys.journey,
      );
      await firestore.doc('users/$uid/orders/${order.reference}').set({
        ...CloudSerialization.order(order),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await repository.savePreferences(
        uid,
        const SavedPreferences(
          notifications: true,
          checklist: ['Drinking water'],
        ),
      );
      journeys.dispose();
      await repository.signOut();
      expect(auth.currentUser, isNull);
      await repository.signIn(email, password);
      expect(auth.currentUser!.uid, uid);
      final restoredOrders = await repository
          .watchOrders(uid)
          .firstWhere((value) => value.isNotEmpty)
          .timeout(const Duration(seconds: 20));
      final restoredJourneys = await repository
          .watchJourneys(uid)
          .firstWhere((value) => value.isNotEmpty)
          .timeout(const Duration(seconds: 20));
      expect(restoredOrders.single.reference, order.reference);
      expect(restoredOrders.single.totalPaise, 17000);
      expect(restoredJourneys.single.journey.destination, 'Thrissur');
      expect(
        (await repository.watchPreferences(uid).first).notifications,
        isTrue,
      );
      final profile = await firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      expect(profile.data()!['displayName'], 'Android traveler');
      expect(profile.data()!.containsKey('password'), isFalse);
      await repository.updateProfile('Updated traveler');
      expect((await repository.authChanges.first)!.name, 'Updated traveler');
      await repository.signOut();
      await app.delete();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Firebase account and history checks passed.'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
