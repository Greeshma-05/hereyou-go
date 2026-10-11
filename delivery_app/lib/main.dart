import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'live/delivery_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const emulator = kDebugMode && bool.fromEnvironment('FIREBASE_USE_EMULATORS');
  try {
    final app = await Firebase.initializeApp(
      name: emulator ? 'delivery-local' : null,
      options: FirebaseOptions(
        apiKey: emulator
            ? 'AIzaSy000000000000000000000000000000000'
            : kIsWeb
            ? 'AIzaSyCnz6IuG-DEuZGFfPZK8L1n1ggofKt4TpQ'
            : 'AIzaSyAofm8As8kD46HWvvLfLwHDMTEkf_D_8oU',
        appId: emulator
            ? '1:1234567890:android:deliverylocal'
            : kIsWeb
            ? '1:552570953286:web:5d9897a8c7b823a404b447'
            : '1:552570953286:android:603e7fe6e911a65404b447',
        projectId: emulator ? 'demo-route-rescue' : 'arjunlayover',
        messagingSenderId: emulator ? '1234567890' : '552570953286',
        authDomain: 'arjunlayover.firebaseapp.com',
        storageBucket: 'arjunlayover.firebasestorage.app',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app),
        db = FirebaseFirestore.instanceFor(app: app);
    db.settings = const Settings(persistenceEnabled: false);
    if (emulator) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      await auth.useAuthEmulator(
        host,
        const int.fromEnvironment(
          'FIREBASE_AUTH_EMULATOR_PORT',
          defaultValue: 9099,
        ),
      );
      db.useFirestoreEmulator(
        host,
        const int.fromEnvironment(
          'FIREBASE_FIRESTORE_EMULATOR_PORT',
          defaultValue: 8080,
        ),
      );
    }
    runApp(
      DeliveryApp(
        auth: auth,
        repository: FulfillmentRepository.forApp(app),
        localTesting: emulator,
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Delivery services could not start. Check your connection and restart the app.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
