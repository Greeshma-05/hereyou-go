import '../models/vendor_model.dart';
import '../models/product_model.dart';

class MerchantAccount {
  const MerchantAccount({
    required this.ownerName,
    required this.email,
    required this.phone,
    this.licenseNumber = '',
  });
  final String ownerName;
  final String email;
  final String phone;
  final String licenseNumber;
}

abstract class MerchantRepository {
  Stream<String?> get authChanges;
  String? get email;
  Future<void> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Stream<Vendor?> watchShop(String uid);
  Stream<List<Product>> watchProducts(String uid);
  Future<MerchantAccount?> account(String uid);
  Future<void> saveShop(
    Vendor shop,
    MerchantAccount account, {
    required bool creating,
  });
  Future<void> saveProduct(
    String uid,
    Product product, {
    required bool creating,
  });
}
