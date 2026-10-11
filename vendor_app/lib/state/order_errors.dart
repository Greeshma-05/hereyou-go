import 'package:firebase_core/firebase_core.dart';

String orderError(Object error) {
  if (error is StateError) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'This account cannot access these orders. Sign in with the account that owns this shop.',
      'unauthenticated' => 'Your session expired. Sign out and log in again.',
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' => 'Check your connection and try again.',
      _ => 'Orders could not sync. Please retry.',
    };
  }
  return 'Could not complete this action. Please retry.';
}
