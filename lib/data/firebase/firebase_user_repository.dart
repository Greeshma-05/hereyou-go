import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/journey_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../user_repository.dart';
import '../fulfillment_repository.dart';
import '../courier_tracking_source.dart';
import 'cloud_serialization.dart';

class FirebaseUserRepository implements UserRepository, LiveOrderRepository {
  FirebaseUserRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    FulfillmentRepository? fulfillment,
  }) : _auth = auth,
       _db = firestore,
       _fulfillment = fulfillment;
  final FulfillmentRepository? _fulfillment;
  FulfillmentRepository get fulfillment =>
      _fulfillment ?? FulfillmentRepository.forApp(_db.app);
  @override
  CourierTrackingSource get tracking => FirebaseCourierTracking(_db);
  @override
  Future<RescueOrder> placeLiveOrder(RescueOrder order) =>
      fulfillment.place(_auth.currentUser!.uid, order);
  @override
  Future<void> cancelOrder(String reference) =>
      fulfillment.transition(reference, 'cancelled');
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  @override
  Stream<Customer?> get authChanges => _auth.userChanges().map(
    (user) => user == null
        ? null
        : Customer(
            uid: user.uid,
            name: user.displayName?.trim().isNotEmpty == true
                ? user.displayName!
                : 'Traveler',
            contact: user.email ?? '',
          ),
  );
  Future<void> _saveProfile(User user) async {
    final ref = _user(user.uid);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      tx.set(ref, {
        'displayName': user.displayName ?? 'Traveler',
        'email': user.email ?? '',
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _saveProfile(result.user!);
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user!.updateDisplayName(name.trim());
    await _saveProfile(_auth.currentUser!);
  }

  @override
  Future<void> signOut() => _auth.signOut();
  @override
  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
  @override
  Future<void> updateProfile(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to save your profile.');
    await user.updateDisplayName(name.trim());
    await _saveProfile(_auth.currentUser!);
  }

  @override
  Stream<List<RescueOrder>> watchOrders(String uid) => _user(uid)
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => CloudSerialization.readOrder(doc.data()))
            .toList(),
      );
  @override
  Stream<List<SavedJourney>> watchJourneys(String uid) => _user(uid)
      .collection('journeys')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return SavedJourney(
            id: doc.id,
            journey: CloudSerialization.readJourney(
              CloudSerialization.map(data['journey']),
            ),
            savedAt: CloudSerialization.date(
              data['createdAt'] ?? data['clientCreatedAt'],
            ),
          );
        }).toList(),
      );
  @override
  Future<void> saveOrder(String uid, RescueOrder order) async {
    if (_auth.currentUser?.uid != uid) {
      throw StateError('Sign in to place an order.');
    }
    await fulfillment.place(uid, order);
  }

  @override
  Future<void> saveJourney(String uid, SavedJourney saved) =>
      _user(uid).collection('journeys').doc(saved.id).set({
        'schemaVersion': 1,
        'journey': CloudSerialization.journey(saved.journey),
        'clientCreatedAt': Timestamp.fromDate(saved.savedAt),
        'createdAt': FieldValue.serverTimestamp(),
      });
  @override
  Stream<SavedPreferences> watchPreferences(String uid) => _user(uid)
      .collection('preferences')
      .doc('general')
      .snapshots()
      .map((doc) {
        final data = doc.data();
        return SavedPreferences(
          notifications: data?['notifications'] as bool? ?? false,
          checklist: List<String>.from(data?['checklist'] as List? ?? []),
        );
      });
  @override
  Future<void> savePreferences(String uid, SavedPreferences prefs) =>
      _user(uid).collection('preferences').doc('general').set({
        'notifications': prefs.notifications,
        'checklist': prefs.checklist,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
