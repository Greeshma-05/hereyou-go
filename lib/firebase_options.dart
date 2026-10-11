import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public Firebase configuration for the supplied arjunlayover project.
/// Native apps require their own Firebase registration, not the web app ID.
/// Build-time values also support the isolated local Firebase emulators.
/// Firebase API keys identify a project; Firestore rules enforce data access.
class DefaultFirebaseOptions {
  static const _apiKeyOverride = String.fromEnvironment('FIREBASE_API_KEY');
  static String get apiKey => _apiKeyOverride.isNotEmpty
      ? _apiKeyOverride
      : (kIsWeb
            ? 'AIzaSyCnz6IuG-DEuZGFfPZK8L1n1ggofKt4TpQ'
            : 'AIzaSyAofm8As8kD46HWvvLfLwHDMTEkf_D_8oU');
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'arjunlayover',
  );
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static String get platformAppId => appId.isNotEmpty
      ? appId
      : (kIsWeb
            ? '1:552570953286:web:5d9897a8c7b823a404b447'
            : defaultTargetPlatform == TargetPlatform.android
            ? '1:552570953286:android:6afe9be778d2ae0c04b447'
            : '');
  static bool get configured =>
      apiKey.isNotEmpty && projectId.isNotEmpty && platformAppId.isNotEmpty;
  static FirebaseOptions get currentPlatform => FirebaseOptions(
    apiKey: apiKey,
    appId: platformAppId,
    projectId: projectId,
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '552570953286',
    ),
    authDomain: const String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'arjunlayover.firebaseapp.com',
    ),
    storageBucket: const String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'arjunlayover.firebasestorage.app',
    ),
  );
}
