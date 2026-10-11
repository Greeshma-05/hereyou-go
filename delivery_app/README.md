# Here You Go Delivery

The Android and web delivery app now uses the same `arjunlayover` Firebase project and shared order backend as the customer app (repository root) and `vendor_app`.

**Deployment status, 11 October 2026:** Firebase Auth, Firestore rules/indexes and the Render Free order service are live for `arjunlayover`. Firebase billing remains disabled. Customer checkout, vendor acceptance/assignment and courier handover passed a live three-account test; temporary fixtures were removed. All three apps use `https://here-you-go-orders.onrender.com/fulfillment`. See [backend setup](../functions/README.md).

Profile sync errors distinguish denied database access, expired sessions and network failures. **Retry profile sync** restarts a failed listener; successful snapshots clear the profile error without hiding unrelated location failures. Install the updated APK to use the direct profile save path; older APKs still call the undeployed registration function.

The current release is `../releases/connected/here-you-go-delivery-0.1.3.apk` (version code 4). It supports Android 7+ on ARM32, ARM64 and x86-64. Signature verification, ZIP/64-bit native 16 KB alignment, installation over the existing app and release startup passed. It retains the existing development signing certificate; store publishing still needs production signing configuration.

## Connected workflow

1. A signed-in customer orders published, available products for their saved delivery pin. The server checks prices and stock, reserves inventory, generates a private handover code, and records a cash-on-delivery order.
2. The vendor opens **Customer orders**, accepts the order, starts preparing it, and marks it ready.
3. A registered partner goes online with precise foreground GPS. **Nearby** shows unassigned preparing/ready pickups within **5 km of the vendor**, with straight-line pickup/delivery distances, item counts and delivery fees. It refreshes every 20 seconds.
4. **Accept delivery** atomically assigns the order, or the vendor chooses **Assign delivery partner** for an accepted/preparing/ready order and selects an online, free partner within 5 km. Vendor-assigned orders appear automatically in the delivery app; **Open active delivery** shows the job. Each order has one partner and each partner can have one active delivery. Customer address/instructions become available after assignment.
5. **Active** provides shop/customer navigation, pickup confirmation after the vendor marks the order ready, the cash total to collect, and handover-code verification.
6. Statuses and assigned-partner location update in the customer's order screen/map. Completed and cancelled deliveries remain in **History**. Completed delivery fees are a summary, not a payment or settlement ledger.

Location sharing stops when the app goes into the background, the partner goes offline, or GPS fails. Go online again after returning from navigation. This implementation does not provide background tracking or push notifications; live listeners/polling update open apps. The delivery app waits up to 30 seconds for a GPS reading no older than 45 seconds with accuracy within 150 m; cached and inaccurate readings are skipped. The server independently rejects readings older than 90 seconds. The backend rechecks the exact 5 km radius at assignment. Device-reported GPS is not hardware attestation.

Cash on delivery is the only payment method. Prescription-required products cannot be ordered until a pharmacy verification workflow exists. Customer cancellation is available before vendor acceptance; vendors can cancel before pickup, restoring reserved inventory.

## Validation

The Android workflow test passed with separate customer, vendor and partner sessions, including server-created checkout, vendor UI processing, courier profile setup, nearby discovery, vendor selection and atomic assignment, pickup, OTP handover, mirrored customer status and delivery history. Courier self-claiming is also covered by the backend tests. Screenshots in `screenshots/` were visually reviewed. GPS is deterministic in this integration test; shared location service permissions and lifecycle recovery are handled in the app, with four additional state tests for denied GPS and backgrounding races.

All 67 delivery tests, 64 customer tests, 4 vendor tests and 21 backend/security tests passed. Android debug builds for all three apps and the delivery web build passed.

The `0.1.1+2` profile fix passed 69 delivery tests and 26 Firebase security/workflow tests, plus static analysis of the shared and delivery apps. The native Android workflow also passed profile creation and editing, preserved the original registration timestamp, used the edited courier name on assignment, and completed pickup and verified handover. A live Firebase check created, edited and reloaded a temporary courier profile, confirmed guest reads and direct online-status changes were denied, and removed both the temporary document and Auth account afterward. Billing was not changed.

## Run

From this folder:

```sh
flutter pub get
flutter run -d emulator-5554
# Or: flutter run -d chrome
```

Android package: **com.hereyougo.delivery**. Firebase app ID: `1:552570953286:android:603e7fe6e911a65404b447`. This is different from the customer (`com.app`) and vendor (`com.hereyougo.vendor`) packages, so all three can be installed together. The downloaded `google-services.json` contains the correct delivery registration.

The production entry point is `lib/main.dart`. Original ZIP prototype screens and tests are retained; `lib/main_demo.dart` explicitly launches the old simulation. Signed-in production sessions never fall back to mock deliveries. `README.original.md` documents the original prototype and is historical.

The live interface imports the customer/vendor app's shared charcoal/lime Material theme, order cards and formatting. A contrast button cycles the same accessible color palettes. System font scaling is preserved.

## Local end-to-end testing

Install Node.js 22, Firebase CLI, Java 21+, and the Flutter version used by the root app. From the repository root:

```sh
npm ci
npm ci --prefix functions
npm run test:fulfillment
```

That starts isolated emulators on ports 8180 (Firestore), 9199 (Auth), and 5101 (Functions), then tests all three roles, radius boundaries, competing claims, stock reservations, retry safety, cancellation, OTP lockout, and data access restrictions. It never contacts the live database.

For interactive Android testing, keep this running at the root:

```sh
firebase emulators:start --config firebase.test.json --only firestore,auth,functions --project demo-route-rescue
```

Then from this folder:

```sh
flutter run -d emulator-5554 --dart-define-from-file=../config/firebase.integration.json
```

Use the same configuration file for customer and vendor builds. For a browser or a physical device, override `FIREBASE_EMULATOR_HOST` appropriately; browser localhost is `127.0.0.1`. The fake emulator API key is syntactically valid because Android's Functions SDK validates its format; it is not a production credential.

The native workflow test creates independent customer, vendor and partner Firebase SDK sessions, exercises vendor and delivery UI, and verifies status synchronization and handover. It uses an injected deterministic GPS fixture:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/fulfillment_flow_test.dart -d emulator-5554 \
  --dart-define-from-file=../config/firebase.integration.json
```

Screenshots are written to `screenshots/`. See [backend deployment instructions](../functions/README.md) for the remaining production step.

## Standalone order service

The shared service can run on Render Free without Firebase billing. All three apps require the same deployed `FULFILLMENT_URL`; use the [backend guide](../functions/README.md) and the root `scripts/build_connected_apks.py` script. The 5 km assignment checks, location freshness checks and order writes remain server-controlled.


## GPS controls

Release 0.1.3 uses the phone’s native GPS with no default or demo city. **Use my current location** works offline without publishing availability, displays coordinates/accuracy/capture time, and refreshes server presence when online. Location permission and device GPS settings remain accessible. The map follows new coordinates and has a recenter button. Simulated device locations are labelled. Keep the app open and online to appear to vendors within 5 km.

GPS regression verification: 78 delivery tests and 13 shared location tests passed, including rejection of stale/approximate fixes, stream cancellation on success/timeout, offline GPS inspection without presence writes, coordinate changes sent to the server, map recentering, and completing Go online after the first permission prompt. Static analysis passed.

The native Android GPS test (`integration_test/device_gps_test.dart`) also passed using the production location service and an explicitly injected Android test-provider location. It verified the displayed position, precise accuracy, offline inspection, coordinates passed to the local presence stub, and successful sync UI. This test does not contact Firestore; its mock provider and shell permission were removed/restored afterward.
