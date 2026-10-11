import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'package:route_rescue/models/category.dart';
import 'package:route_rescue/models/product_model.dart';
import 'package:route_rescue/models/vendor_model.dart';
import 'package:here_you_go_vendor/vendor_app.dart';
import 'package:here_you_go_vendor/state/product_validation.dart';

class TestMerchantRepository implements MerchantRepository {
  String? uid = 'vendor';
  Vendor? shop = const Vendor(
    id: 'vendor',
    name: 'Test pharmacy',
    category: Category.medicine,
    position: LatLng(9.98, 76.29),
    area: 'Public test address',
    preparationMinutes: 10,
    rating: 0,
    description: 'Test shop',
    isSample: false,
  );
  final auth = StreamController<String?>.broadcast();
  final shops = StreamController<Vendor?>.broadcast();
  final inventory = StreamController<List<Product>>.broadcast();
  List<Product> items = [];
  int writes = 0;
  @override
  String? get email => 'vendor@example.test';
  @override
  Stream<String?> get authChanges async* {
    yield uid;
    yield* auth.stream;
  }

  @override
  Stream<Vendor?> watchShop(String uid) async* {
    yield shop;
    yield* shops.stream;
  }

  @override
  Stream<List<Product>> watchProducts(String uid) async* {
    yield items;
    yield* inventory.stream;
  }

  @override
  Future<MerchantAccount?> account(String uid) async => const MerchantAccount(
    ownerName: 'Owner',
    email: 'vendor@example.test',
    phone: '+919876543210',
    licenseNumber: 'TEST',
  );
  @override
  Future<void> signIn(String email, String password) async {
    uid = 'vendor';
    auth.add(uid);
  }

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);
  @override
  Future<void> signOut() async {
    uid = null;
    auth.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> saveShop(
    Vendor shop,
    MerchantAccount account, {
    required bool creating,
  }) async {
    this.shop = shop;
    shops.add(shop);
  }

  @override
  Future<void> saveProduct(
    String uid,
    Product product, {
    required bool creating,
  }) async {
    writes++;
    items = [product];
    inventory.add(items);
  }

  Future<void> dispose() async {
    await auth.close();
    await shops.close();
    await inventory.close();
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  test('prices use exact integer paise and reject malformed amounts', () {
    expect(priceInPaise('123.45'), 12345);
    expect(priceInPaise('0.01'), 1);
    for (final value in ['0', '-1', '1.234', 'NaN', '100000.01']) {
      expect(priceInPaise(value), isNull);
    }
  });
  test('expiry rejects invalid dates and expired published products', () {
    expect(expiryError('2030-02-31', required: true), isNotNull);
    expect(expiryError('', required: true), isNotNull);
    expect(expiryError('2020-01-01', required: true), isNotNull);
    expect(expiryError('2020-01-01', required: true, allowPast: true), isNull);
    expect(expiryError('2030-12-31', required: true), isNull);
  });
  testWidgets(
    'medical shop adds a labeled product and logout removes vendor state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestMerchantRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(VendorApp(repository: repo));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Add product'));
      await fill(tester, 'Medicine name', 'Test label');
      await fill(tester, 'Strength / concentration', '10 mg');
      await fill(tester, 'Dosage form', 'Tablet');
      await fill(tester, 'Pack size / unit', 'Strip of 10');
      await fill(tester, 'Manufacturer', 'Test manufacturer');
      await fill(tester, 'Expiry date (YYYY-MM-DD)', '2030-12-31');
      await fill(tester, 'Price (₹)', '12.50');
      await fill(tester, 'Available stock', '15');
      await fill(tester, 'Description', 'Product label details');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save product'));
      expect(repo.writes, 1);
      expect(repo.items.single.pricePaise, 1250);
      expect(repo.items.single.strength, '10 mg');
      expect(repo.items.single.prescriptionRequired, true);
      expect(find.text('Test label'), findsOneWidget);
      await tap(tester, find.byTooltip('Sign out'));
      expect(find.text('Create vendor account'), findsOneWidget);
      expect(find.text('Test pharmacy'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'narrow large-text shop setup validates the location before saving',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = TestMerchantRepository()..shop = null;
      addTearDown(repo.dispose);
      await tester.pumpWidget(VendorApp(repository: repo));
      await tester.pumpAndSettle();
      await fill(tester, 'Shop name', 'Test store');
      await fill(tester, 'Shop address', 'Test public entrance');
      await fill(tester, 'About your shop', 'Essential items');
      await fill(tester, 'Owner name', 'Test Owner');
      await fill(tester, 'Business phone', '+919876543210');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save shop'));
      expect(
        find.text('Confirm the shop entrance on the map first.'),
        findsOneWidget,
      );
      expect(repo.shop, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
