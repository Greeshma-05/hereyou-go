# Here You Go Vendor

Separate Flutter app for vendors, sharing Firebase project **arjunlayover** and the catalog models/repositories in the parent customer app. Keep this folder inside the repository: `route_rescue: path: ..` shares the schema, theme, map picker and location service.

## Run

```sh
cd vendor_app
flutter pub get
flutter run -d emulator-5554
# Or use the existing Firebase web registration:
flutter run -d chrome
```

Android package: **com.hereyougo.vendor**. Firebase Android app ID: **1:552570953286:android:d1a9b1d05162133204b447**. Its configuration is included in `android/app/google-services.json`; the customer package remains `com.app`. Both apps can be installed together and keep separate native sign-in sessions. Firebase email/password accounts belong to the same project, so an existing customer can log in and register a shop using the same credentials. See the official [Firebase project/app model](https://firebase.google.com/docs/projects/learn-more).

## Vendor workflow

1. Register with email/password or log in. Password reset is available.
2. Enter the shop name, type, address, description and preparation time. Pin the shop entrance manually or use device GPS. Customer distance uses this confirmed map pin, so verify it marks the actual shop entrance; a typed address alone does not set coordinates. Editing the address clears the pin and requires confirmation again.
3. Enter private owner/contact details. Medical shops also require a license number. This is self-reported and does not grant a verified badge.
4. Publish or hide the shop and mark it open/closed. Shop category is fixed after registration so existing products retain consistent categories.
5. Add/edit products, prices in rupees, pack sizes, descriptions and whole-number stock. Medicine entries include strength/concentration, dosage form, manufacturer and expiry, with optional generic name/brand and a prescription-required flag. These are catalog labels, not treatment or patient dosing recommendations.
6. Turn off **Publish product** to archive an item. Stock zero displays as sold out. Expired products are excluded from customer searches. Saved inventory is shown after Firestore confirms writes; save errors retain the form.
7. Open **Customer orders**. The dashboard shows a live new-order count, and the inbox separates **Active**, **New**, **Needs partner** and **History**. Only completed customer checkouts create shop orders; guest previews do not.
8. Tap **Accept order**, then **Assign delivery partner**. Available partners are listed nearest first within **5 km of the order's saved shop pickup pin**, with name, vehicle and distance. Partners must be online, unassigned, and have a GPS fix no older than 90 seconds with accuracy within 150 m. Refresh if none are available.
9. Choose **Assign [name]**. The backend rechecks ownership, order status, availability and radius in one transaction. It updates the customer order and the partner's active delivery together. Continue with **Start preparing** and **Mark ready for pickup**; assignment does not advance preparation status.

## Shared database

| Path | Access and contents |
| --- | --- |
| `vendorAccounts/{uid}` | Owner-only contact name, email, phone and license number |
| `vendors/{uid}` | Public when published: shop name/type, address, coordinates, description, preparation time and open/closed state |
| `vendors/{uid}/products/{productId}` | Public when both shop and product are published: price in integer paise, stock, label fields and publication state |

Owners may edit only their own shop/products. Vendor clients cannot grant verification/admin roles, change ownership, read another account's private contact details, read customer history or change customer order status. Archiving preserves order snapshots; clients cannot delete catalog documents. Customer order history remains under the original private `users/{uid}` paths.

The customer app listens for published shops in a conservative 21 km bounding box (latitude-only fallback at the dateline/poles), then applies exact distance checks. It subscribes to those shops' published inventory, excludes expired items, and includes all shops **within 7 km for buses** and **within 20 km for trains**, including the closest shops. Home and Explore share location/mode controls and show the active search coordinates. New published records, price/stock changes, shop moves and hidden records update results without restarting the customer app. Search includes product name, generic name, brand, manufacturer, strength and form. In-stock results come first. The query currently caps the area at 200 shops and explicitly indicates truncation; a larger rollout should add paginated/geohash queries and capacity monitoring. See [Firestore range queries](https://firebase.google.com/docs/firestore/query-data/multiple-range-fields).

Deployment uses the root `firestore.rules` and `firestore.indexes.json`:

The tested vendor catalog rules and location indexes were deployed to `arjunlayover` on 11 October 2026 with the project owner's approval. Both indexes finished building, and live read-only checks passed for the location queries and denial of anonymous access to private vendor/customer paths. No production test inventory was created.

```sh
cd ..
firebase deploy --only firestore:rules,firestore:indexes --project arjunlayover
```

**Customer orders** supports accepting, assigning a nearby partner, preparing, marking ready and cancelling orders. Vendors can assign accepted/preparing/ready orders; delivery partners can also claim unassigned preparing/ready orders within 5 km. Assignment races cannot give an order to two partners or give one partner two active deliveries. Vendors cannot assign their own account or the ordering customer's account. Candidate searches expose no private phone numbers or exact unassigned partner coordinates. Cancellation before pickup restores stock and releases the assigned partner. Updates are live while the apps are open; background push notifications are not implemented. Cash on delivery is supported by the prepared shared backend. Prescription verification, online payments, product uploads and vendor settlement are not implemented.

**Order service:** the standalone Node.js backend is prepared for Render Free, preserving Firebase Spark billing. Fulfillment indexes and rules are deployed. Build all three apps with the deployed `FULFILLMENT_URL`; see [backend setup](../functions/README.md). The Render service is live in Singapore and the full order/assignment/handover flow has passed a live check. Install vendor 0.1.3 with customer and delivery 0.1.2 or later.

Partner discovery refreshes automatically every 10 seconds while its screen is visible and immediately when the vendor returns to the app. A partner who comes online after an empty search now appears without reopening the screen. Slow requests cannot overlap, and polling stops when the screen closes or the app is backgrounded. Delivery partners must keep their delivery app open, online and sharing precise GPS. No billing or production order data was changed for this refresh fix.

The release APK is `../releases/connected/here-you-go-vendor-0.1.3.apk` (version code 4, approximately 55 MB). It supports Android 7+ on ARM32, ARM64 and x86-64. Signature checks, 16 KB ZIP/native alignment and installation over the existing vendor app passed. It retains the existing development signing certificate; store publishing still needs production signing configuration.

## Local verification

Tests use `demo-route-rescue`, never production accounts or inventory.

Vendor assignment validation: 14 vendor tests passed, including automatic discovery after an empty result, removal of unavailable partners, resume refresh and slow-request/disposal races. The existing 35 backend/security tests passed during backend deployment, including incoming-order subscriptions, acceptance, empty/error/retry screens, disabled duplicate submissions, 5 km boundaries, stale/offline/busy candidates, cross-account privacy and concurrent vendor/partner assignment. Static analysis passed for the workspace and vendor app.

The native Android test in `delivery_app/integration_test/fulfillment_flow_test.dart` passed a customer checkout, vendor acceptance/preparation, automatic discovery after a partner comes online while the vendor is viewing an empty list, assignment, receipt in the delivery app, pickup and verified handover. It uses independent Firebase sessions and deterministic GPS against the isolated emulators. Screenshots: [nearby partners](../delivery_app/screenshots/vendor-nearby-partners.png) and [assigned order](../delivery_app/screenshots/vendor-assigned-order.png).

```sh
# From the repository root:
npm run test:rules
flutter test
firebase emulators:start --only auth,firestore --project demo-route-rescue

# In another terminal:
cd vendor_app
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/vendor_catalog_test.dart -d emulator-5554 \
  --dart-define-from-file=config/firebase.emulator.json
```

The Android integration test passed: it registers a medical shop using fictional details, pins it at a fixed test coordinate, adds a labeled medicine and checks discovery from a separately initialized, signed-out customer Firebase app. It checks price/stock updates and product/shop hiding. Screenshots are saved in `screenshots/`. The vendor Flutter suite passed all 4 tests, and the shared Firebase rules suite passed all 13. A persistent **LOCAL TEST DATABASE** banner distinguishes vendor emulator runs. Emulator routing and local HTTP access are debug-only; normal builds use `arjunlayover`.

The root `integration_test/catalog_sync_test.dart` also passed on Android with separate native vendor/customer clients: publishing after the customer opens, price/stock edits, 0/8/25 km shop moves, bus/train filtering, hiding and republishing all update the customer UI. Run it from the root with the Firebase emulators running:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/catalog_sync_test.dart -d emulator-5554 \
  --dart-define=FIREBASE_USE_EMULATORS=true
```
