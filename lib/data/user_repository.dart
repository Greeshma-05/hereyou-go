import '../models/user_model.dart';
import '../models/journey_model.dart';
import '../models/order_model.dart';

class SavedPreferences {
  const SavedPreferences({
    this.notifications = false,
    this.checklist = const [],
  });
  final bool notifications;
  final List<String> checklist;
}

/// Auth credentials go to the authentication provider, never to user documents.
abstract class UserRepository {
  Stream<Customer?> get authChanges;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String name, String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updateProfile(String name);
  Stream<List<RescueOrder>> watchOrders(String uid);
  Stream<List<SavedJourney>> watchJourneys(String uid);
  Stream<SavedPreferences> watchPreferences(String uid);
  Future<void> saveOrder(String uid, RescueOrder order);
  Future<void> saveJourney(String uid, SavedJourney journey);
  Future<void> savePreferences(String uid, SavedPreferences preferences);
}
