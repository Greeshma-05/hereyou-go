import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vendor_model.dart';
import '../../models/product_model.dart';
import '../merchant_repository.dart';
import 'catalog_serialization.dart';

class FirebaseMerchantRepository implements MerchantRepository {
  FirebaseMerchantRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _db = firestore;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  @override
  Stream<String?> get authChanges =>
      _auth.authStateChanges().map((u) => u?.uid);
  @override
  String? get email => _auth.currentUser?.email;
  @override
  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
  @override
  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
  @override
  Stream<Vendor?> watchShop(String uid) => _db
      .collection('vendors')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((doc) => !doc.metadata.hasPendingWrites)
      .map(
        (doc) =>
            doc.exists ? CatalogSerialization.readShop(uid, doc.data()!) : null,
      );
  @override
  Stream<List<Product>> watchProducts(String uid) => _db
      .collection('vendors')
      .doc(uid)
      .collection('products')
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map(
        (s) =>
            s.docs
                .map(
                  (d) => CatalogSerialization.readProduct(uid, d.id, d.data()),
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
      );
  @override
  Future<MerchantAccount?> account(String uid) async {
    final d = (await _db.collection('vendorAccounts').doc(uid).get()).data();
    return d == null
        ? null
        : MerchantAccount(
            ownerName: d['ownerName'] as String,
            email: d['email'] as String,
            phone: d['phone'] as String,
            licenseNumber: d['licenseNumber'] as String,
          );
  }

  @override
  Future<void> saveShop(
    Vendor shop,
    MerchantAccount account, {
    required bool creating,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection('vendorAccounts').doc(shop.id), {
      'ownerName': account.ownerName,
      'email': account.email,
      'phone': account.phone,
      'licenseNumber': account.licenseNumber,
      'updatedAt': FieldValue.serverTimestamp(),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('vendors').doc(shop.id), {
      ...CatalogSerialization.shop(shop),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> saveProduct(
    String uid,
    Product product, {
    required bool creating,
  }) async {
    final products = _db.collection('vendors').doc(uid).collection('products');
    final ref = creating
        ? products.doc()
        : products.doc(product.id.split('/').last);
    await ref.set({
      ...CatalogSerialization.product(product),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
