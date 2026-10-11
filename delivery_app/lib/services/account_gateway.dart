import '../models/firebase_account.dart';

/// Account access is separate from the offline delivery repository.
abstract interface class AccountGateway {
  bool get isConfigured;
  String get signInDescription;
  Future<FirebaseAccount> signIn(String email, String password);
  Future<FirebaseAccount> createAccount(
    String name,
    String email,
    String password,
  );
  Future<AccountProfile?> loadProfile();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);
  final String message;
}

class UnavailableAccountGateway implements AccountGateway {
  const UnavailableAccountGateway();

  @override
  bool get isConfigured => false;
  @override
  String get signInDescription =>
      'Firebase sign-in is not configured for this build. Demo Mode is available.';
  @override
  Future<FirebaseAccount> signIn(String email, String password) async {
    throw const AccountFailure(
      'Firebase sign-in is not configured for this build. No sign-in occurred. Choose Try Demo Mode.',
    );
  }

  @override
  Future<AccountProfile?> loadProfile() async => null;
  @override
  Future<void> sendPasswordReset(String email) async {
    throw const AccountFailure(
      'Firebase password recovery is not configured for this build.',
    );
  }

  @override
  Future<FirebaseAccount> createAccount(
    String name,
    String email,
    String password,
  ) async {
    throw const AccountFailure(
      'Firebase account creation is not configured for this build. Choose Try Demo Mode.',
    );
  }

  @override
  Future<void> signOut() async {}
}
