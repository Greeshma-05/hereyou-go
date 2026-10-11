import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/firebase_account.dart';
import 'account_gateway.dart';

class FirebaseAccountGateway implements AccountGateway {
  FirebaseAccountGateway(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static Future<AccountGateway> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const UnavailableAccountGateway();
    }
    try {
      // Android options come from the matching google-services.json resources.
      final app = await Firebase.initializeApp();
      if (app.options.projectId != 'arjunlayover') {
        return const UnavailableAccountGateway();
      }
      final firestore = FirebaseFirestore.instanceFor(app: app);
      // Account reads should not expose a previous user's disk-cached profile.
      firestore.settings = const Settings(persistenceEnabled: false);
      return FirebaseAccountGateway(
        FirebaseAuth.instanceFor(app: app),
        firestore,
      );
    } catch (_) {
      // Missing configuration must not prevent the offline app from opening.
      return const UnavailableAccountGateway();
    }
  }

  @override
  bool get isConfigured => true;
  @override
  String get signInDescription =>
      'Use your RouteRescue email and password, or create an account below. Customer accounts in this project can sign in here too.';

  @override
  Future<FirebaseAccount> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AccountFailure(
          'Sign-in did not return an account. Please retry.',
        );
      }
      return FirebaseAccount(
        uid: user.uid,
        email: user.email ?? email.trim(),
        name: user.displayName,
      );
    } on FirebaseAuthException catch (error) {
      throw AccountFailure(authErrorMessage(error.code));
    }
  }

  @override
  Future<FirebaseAccount> createAccount(
    String name,
    String email,
    String password,
  ) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AccountFailure(authErrorMessage(error.code, creatingAccount: true));
    }
    final user = credential.user;
    if (user == null) {
      throw const AccountFailure(
        'Account creation did not return a user. Try signing in before retrying.',
      );
    }

    String? setupMessage;
    try {
      await user.updateDisplayName(name.trim());
      final reference = _firestore.collection('users').doc(user.uid);
      // Preserve any existing shared customer profile; never add client-set roles.
      await _firestore
          .runTransaction((transaction) async {
            final existing = await transaction.get(reference);
            if (!existing.exists) {
              transaction.set(reference, {
                'displayName': name.trim(),
                'email': user.email ?? email.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          })
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Auth has already succeeded. Retrying signup would create a duplicate error.
      setupMessage = 'Your account was created and you are signed in, but profile setup could not finish. You can still log in with your email and password. Try Reload profile; if it stays missing, contact your administrator.';
    }
    return FirebaseAccount(
      uid: user.uid,
      email: user.email ?? email.trim(),
      name: name.trim(),
      setupMessage: setupMessage,
    );
  }

  @override
  Future<AccountProfile?> loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AccountFailure('Sign in again to load your account.');
    }
    try {
      // The supplied customer rules permit only this user's own profile read.
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      if (_auth.currentUser?.uid != uid) {
        throw const AccountFailure('Your account changed. Sign in again.');
      }
      final data = snapshot.data();
      if (data == null) return null;
      final name = data['displayName'];
      final email = data['email'];
      if (name is! String || email is! String) {
        throw const AccountFailure('The saved account profile is incomplete.');
      }
      return AccountProfile(displayName: name, email: email);
    } on TimeoutException {
      throw const AccountFailure(
        'Account loading timed out. Check your connection and retry.',
      );
    } on FirebaseException catch (error) {
      throw AccountFailure(
        error.code == 'permission-denied'
            ? 'This account cannot read its saved profile. Check account access with your administrator.'
            : 'Could not load the saved profile. Check your connection and retry.',
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep the response neutral whether or not this email is registered.
      if (error.code == 'user-not-found') return;
      throw AccountFailure(authErrorMessage(error.code));
    }
  }

  static String authErrorMessage(
    String code, {
    bool creatingAccount = false,
  }) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-login-credentials' => 'The email or password is incorrect.',
    'invalid-email' => 'Enter a valid email address.',
    'email-already-in-use' => 'An account already uses this email. Select Back to login and sign in with its password.',
    'weak-password' || 'password-does-not-meet-requirements' => 'Choose a stronger password. Use at least 6 characters and meet any additional requirements set for this Firebase project.',
    'user-disabled' =>
      'This account has been disabled. Contact your administrator.',
    'too-many-requests' => 'Too many sign-in attempts. Please try again later.',
    'network-request-failed' =>
      'Could not reach sign-in. Check your connection and retry.',
    'operation-not-allowed' => 'Email/password authentication is not enabled. In Firebase project arjunlayover, open Authentication > Sign-in method and enable Email/Password.',
    'invalid-api-key' || 'app-not-authorized' || 'configuration-not-found' =>
      'Firebase sign-in setup is incomplete. Contact your administrator.',
    _ =>
      creatingAccount
          ? 'Could not create your account. Check your connection and try again.'
          : 'Sign-in failed. Please try again.',
  };
}
