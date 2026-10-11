import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_rescue/data/firebase/firebase_merchant_repository.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'vendor_app.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MerchantRepository? repository;
  FulfillmentRepository? fulfillment;
  String? setupError;
  const emulators =
      kDebugMode && bool.fromEnvironment('FIREBASE_USE_EMULATORS');
  const androidAppId = String.fromEnvironment(
    'VENDOR_FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:552570953286:android:d1a9b1d05162133204b447',
  );
  try {
    if (!kIsWeb && !emulators && androidAppId.isEmpty) {
      throw StateError(
        'Register Android package com.hereyougo.vendor in Firebase project arjunlayover, then set VENDOR_FIREBASE_ANDROID_APP_ID. See vendor_app/README.md.',
      );
    }
    final app = await Firebase.initializeApp(
      name: emulators ? 'vendor-local' : null,
      options: FirebaseOptions(
        apiKey: emulators
            ? 'AIzaSy000000000000000000000000000000000'
            : kIsWeb
            ? 'AIzaSyCnz6IuG-DEuZGFfPZK8L1n1ggofKt4TpQ'
            : const String.fromEnvironment(
                'VENDOR_FIREBASE_API_KEY',
                defaultValue: 'AIzaSyAofm8As8kD46HWvvLfLwHDMTEkf_D_8oU',
              ),
        appId: emulators
            ? '1:1234567890:android:vendorlocal'
            : kIsWeb
            ? '1:552570953286:web:5d9897a8c7b823a404b447'
            : androidAppId,
        projectId: emulators ? 'demo-route-rescue' : 'arjunlayover',
        messagingSenderId: emulators ? '1234567890' : '552570953286',
        authDomain: 'arjunlayover.firebaseapp.com',
        storageBucket: 'arjunlayover.firebasestorage.app',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    db.settings = const Settings(persistenceEnabled: false);
    if (emulators) {
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
    fulfillment = FulfillmentRepository.forApp(app);
    repository = FirebaseMerchantRepository(auth: auth, firestore: db);
  } on StateError catch (e) {
    setupError = e.message;
  } catch (_) {
    setupError =
        'Firebase could not start. Check the vendor app configuration and restart.';
  }
  runApp(
    VendorApp(
      repository: repository,
      fulfillment: fulfillment,
      setupError: setupError,
      localTesting: emulators,
    ),
  );
}
