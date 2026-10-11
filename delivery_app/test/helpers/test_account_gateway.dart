import 'dart:async';

import 'package:routerescue_partner/models/firebase_account.dart';
import 'package:routerescue_partner/services/account_gateway.dart';

class TestAccountGateway implements AccountGateway {
  int signIns = 0;
  int signUps = 0;
  int resetRequests = 0;
  int signOuts = 0;
  int profileReads = 0;
  String? email;
  String? name;
  bool rejectSignOut = false;
  bool rejectProfile = false;
  Completer<FirebaseAccount>? pendingSignIn;
  AccountFailure? signInFailure;
  Completer<FirebaseAccount>? pendingSignUp;
  AccountFailure? signUpFailure;
  Completer<void>? pendingReset;
  Completer<void>? pendingSignOut;
  FirebaseAccount signedInAccount = const FirebaseAccount(
    uid: 'partner-1',
    email: 'partner@example.com',
    name: 'Test Partner',
  );

  @override
  Future<void> sendPasswordReset(String email) async {
    resetRequests++;
    this.email = email;
    await pendingReset?.future;
  }

  @override
  Future<FirebaseAccount> createAccount(
    String name,
    String email,
    String password,
  ) async {
    signUps++;
    this.name = name;
    this.email = email;
    if (signUpFailure != null) throw signUpFailure!;
    return pendingSignUp?.future ??
        FirebaseAccount(uid: 'new-partner', email: email, name: name);
  }

  @override
  bool get isConfigured => true;
  @override
  String get signInDescription => 'Use your Firebase account.';
  @override
  Future<FirebaseAccount> signIn(String email, String password) async {
    signIns++;
    this.email = email;
    if (signInFailure != null) throw signInFailure!;
    return pendingSignIn?.future ?? signedInAccount;
  }

  @override
  Future<AccountProfile?> loadProfile() async {
    profileReads++;
    if (rejectProfile) throw const AccountFailure('Profile access denied.');
    return const AccountProfile(
      displayName: 'Test Partner',
      email: 'partner@example.com',
    );
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (rejectSignOut) throw const AccountFailure('Sign-out failed.');
    await pendingSignOut?.future;
  }
}
