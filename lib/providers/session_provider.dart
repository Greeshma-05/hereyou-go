import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/user_repository.dart';
import '../models/user_model.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider({this.repository, String? setupError}) : error = setupError {
    initializing = repository != null;
    _subscription = repository?.authChanges.listen(
      (value) {
        _customer = value;
        initializing = false;
        _notify();
      },
      onError: (Object failure) {
        initializing = false;
        error = 'Could not restore your sign-in. Please sign in again.';
        _notify();
      },
    );
  }
  final UserRepository? repository;
  StreamSubscription<Customer?>? _subscription;
  Customer? _customer;
  Customer? get customer => _customer;
  bool introduced = false;
  bool initializing = false;
  bool busy = false;
  bool _disposed = false;
  String? error;
  bool get cloudAvailable => repository != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void introduce() {
    introduced = true;
    _notify();
  }

  void enterGuest({String name = 'Traveler', String contact = ''}) {
    _customer = Customer(name: name.trim(), contact: contact.trim());
    error = null;
    _notify();
  }

  // Retained for callers of the original local preview API.
  void enterDemo({String name = 'Traveler', String contact = ''}) =>
      enterGuest(name: name, contact: contact);

  Future<bool> authenticate({
    required bool signup,
    required String name,
    required String email,
    required String password,
  }) async {
    if (busy) return false;
    if (repository == null) {
      error =
          'Account sign-in is not connected yet. You can continue as a guest.';
      _notify();
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      if (signup) {
        await repository!.signUp(name, email, password);
      } else {
        await repository!.signIn(email, password);
      }
      return true;
    } catch (failure) {
      error = _customer?.uid != null
          ? 'You are signed in, but your profile could not sync. Try saving your profile again.'
          : authMessage(failure);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> resetPassword(String email) async {
    if (repository == null || busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await repository!.resetPassword(email);
      return true;
    } catch (failure) {
      error = authMessage(failure);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> updateProfile(String name, String contact) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter your name.');
    final customer = _customer;
    if (customer == null) throw StateError('Sign in to save your profile.');
    if (customer.uid != null) {
      await repository!.updateProfile(name);
      if (_disposed || _customer?.uid != customer.uid) return;
      _customer = Customer(
        uid: customer.uid,
        name: name.trim(),
        contact: customer.contact,
      );
    } else {
      _customer = Customer(name: name.trim(), contact: contact.trim());
    }
    error = null;
    _notify();
  }

  Future<void> logout() async {
    if (_customer?.uid != null) await repository!.signOut();
    _customer = null;
    error = null;
    introduced = true;
    _notify();
  }

  static String authMessage(Object error) {
    if (error is FirebaseAuthException) {
      var code = error.code;
      // Android can wrap setup failures in an unknown/internal-error exception.
      // Recognize only known backend codes; never display the raw server message.
      if (code == 'unknown' || code == 'internal-error') {
        final setupCode = RegExp(
          r'\b(CONFIGURATION_NOT_FOUND|OPERATION_NOT_ALLOWED)\b',
        ).firstMatch(error.message ?? '')?.group(1);
        if (setupCode != null) {
          code = setupCode.toLowerCase().replaceAll('_', '-');
        }
      }
      return switch (code) {
        'email-already-in-use' =>
          'An account with this email already exists. Try logging in.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' =>
          'Choose a stronger password with at least 8 characters.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'The email or password is incorrect.',
        'user-disabled' => 'This account is disabled.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Check your connection and try again.',
        'operation-not-allowed' || 'configuration-not-found' =>
          'Account sign-in has not been enabled yet. You can continue as a guest.',
        _ => 'Could not sign in. Please try again.',
      };
    }
    return 'Could not connect to your account. Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
