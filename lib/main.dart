import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'data/firebase/firebase_user_repository.dart';
import 'data/user_repository.dart';
import 'data/catalog_repository.dart';
import 'data/firebase/firebase_catalog_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'OpenDyslexic',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    /* Guest preferences can remain session-only. */
  }
  UserRepository? repository;
  CatalogRepository catalogRepository = const UnavailableCatalogRepository();
  String? setupError = DefaultFirebaseOptions.configured
      ? null
      : 'Account services need this device’s Firebase configuration. You can browse as a guest.';
  if (DefaultFirebaseOptions.configured) {
    try {
      const useEmulators =
          kDebugMode && bool.fromEnvironment('FIREBASE_USE_EMULATORS');
      final firebaseApp = await Firebase.initializeApp(
        // A separate app keeps local tests isolated from Android's native default app.
        name: useEmulators ? 'route-rescue-local' : null,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: firebaseApp);
      final db = FirebaseFirestore.instanceFor(app: firebaseApp);
      // Keep private documents out of a shared persistent device cache.
      db.settings = const Settings(persistenceEnabled: false);
      if (useEmulators) {
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
      repository = FirebaseUserRepository(auth: auth, firestore: db);
      catalogRepository = FirebaseCatalogRepository(db);
    } catch (_) {
      setupError =
          'Account services could not start. Restart the app to retry, or browse as a guest.';
    }
  }
  runApp(
    RouteRescueApp(
      preferences: preferences,
      repository: repository,
      catalogRepository: catalogRepository,
      restoreLocation: true,
      setupError: setupError,
    ),
  );
}
