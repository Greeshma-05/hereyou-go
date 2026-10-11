# Here You Go

Flutter customer app for travel essentials, with a charcoal/lime interface, supply search, Firebase email/password authentication, and Firestore account history.

The separate [Here You Go Vendor app](vendor_app/README.md) registers shops and manages live Firestore inventory in the same Firebase project. The customer app subscribes to published shops and products near its location. The new [delivery app](delivery_app/README.md) connects a shared cash-on-delivery order workflow: customer checkout, vendor processing, 5 km partner assignment and live tracking. Guest checkout remains a local preview.

The vendor Android app is registered with Firebase. The existing catalog rules and location indexes were tested locally and deployed to `arjunlayover` on 11 October 2026 with the project owner's approval.

## Connected delivery workflow — 11 October 2026

The standalone Node.js service and native three-app workflow are implemented and tested. The owner chose Render Free while keeping Firebase billing disabled. The shared Firestore rules and fulfillment indexes are deployed. The Render Free service is live at `https://here-you-go-orders.onrender.com/fulfillment` and the complete live order flow has been verified. All three apps default to this endpoint; install the connected 0.1.2 releases. Courier contact registration already works directly through owner-only Firestore rules. Live checkout, availability, assignment and delivery transitions use the authenticated order service.

See [delivery app setup](delivery_app/README.md) and [backend deployment](functions/README.md). Use `npm run test:fulfillment` for the isolated three-role backend tests. Live verification used only temporary test accounts, a test shop and test inventory; all fixtures were removed. Existing customer orders and inventory were not changed.

Vendor order management now includes a live dashboard count, active/new/unassigned/history filters, and a nearby-partner picker. After accepting an order, the vendor can assign an online, available partner within 5 km of the order's pickup pin. The prepared backend rechecks GPS freshness, radius and availability transactionally and mirrors the assignment to the customer and delivery apps. These new function actions and the courier location index remain pending deployment; billing is unchanged.

Validation for this integration: 64 customer tests, 4 vendor tests, 67 delivery tests (including location lifecycle checks), and 21 Firebase rules/callable tests passed. A native Android test completed the customer/vendor/partner workflow with independent Firebase sessions and deterministic GPS. All three Android debug builds and the delivery web build passed. [Captured delivery screens](delivery_app/screenshots/) are available locally.

## Firebase configuration and deployment

The supplied Android and web configurations for **arjunlayover** are in `lib/firebase_options.dart`. Android also uses `android/app/google-services.json` and Google Services plugin 4.5.0. The Android application ID is **com.app**, matching the supplied Firebase registration. FlutterFire dependencies manage the native Firebase SDK versions.

Firebase Authentication and the default Firestore database are configured. The project owner published the prepared rules in the console. Live checks verified signup/sign-in, allowed an authenticated user to read its own profile path, and rejected cross-account and anonymous reads. The temporary test account was removed; no test documents were written to the live database. Profile/order/journey writes and restoration were verified with the Firebase emulators and the native Android SDK integration test.

For future Firebase setup or rule changes:

1. Run `firebase login --reauth` with an account that can manage `arjunlayover`.
2. Email/Password authentication is enabled and verified. Keep this provider enabled in the [Firebase console](https://console.firebase.google.com/project/arjunlayover/overview).
3. Create the default **Cloud Firestore** database in Native/Standard mode, initially in production mode. Choose its region deliberately; Mumbai (`asia-south1`) is appropriate for an India-focused app. Retain an existing database's region.
4. Review existing rules if the project already hosts other apps, then deploy:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project arjunlayover
flutter pub get
flutter run -d emulator-5554
```

The supplied configuration is used by default, so no build flags are needed for the live project. Web runs with `flutter run -d chrome`. `config/firebase.android.example.json` shows optional build-time overrides.

Firebase client configuration identifies a project; it does not grant administrative access. Passwords go directly to Firebase Authentication and are never stored in Firestore or local preferences. Never put service-account private keys in the app. See the official [Flutter setup guide](https://firebase.google.com/docs/flutter/setup).

If signup reports `CONFIGURATION_NOT_FOUND`, initialize Authentication in the project console and enable **Email/Password → Save**. Android may wrap this response as `unknown` or `internal-error`; the app recognizes that wrapped response and explains that account sign-in has not been enabled. Updating client configuration alone does not enable this server setting. After Authentication is enabled, Firestore and its rules must also be deployed for profiles/history to sync.

## Stored data

Live orders use the standalone authenticated service documented in [functions/README.md](functions/README.md). Firebase billing stays disabled. All three release apps must be built with the same deployed `FULFILLMENT_URL`; use `scripts/build_connected_apks.py` after Render deployment. Old previews are clearly labeled and are never sent to a shop.

| Location | Contents |
| --- | --- |
| Firebase Authentication | User ID, email, managed credentials, display name, sign-in session |
| `users/{uid}` | Display name, authenticated email, creation/update timestamps |
| `users/{uid}/orders/{reference}` | Item/name/price snapshots, vendor, quantities, fees, total in paise, journey/pickup, status, verification code, timestamps; legacy previews and server-created live order mirrors |
| `users/{uid}/journeys/{id}` | Bus/train details, boarding/destination, departure, pickup, saved timestamps |
| `users/{uid}/preferences/general` | Essentials checklist, notification preference, update timestamp |
| `vendorAccounts/{uid}` | Owner-only contact name, email, phone and pharmacy license number |
| `vendors/{uid}` | Published shop name/type, address, map coordinates, description, preparation time, open/closed state |
| `vendors/{uid}/products/{productId}` | Published product name, price/stock, pack size, description, medicine label fields and expiry |

History is read newest-first. Every saved journey adds an entry under **Profile → Travel history**. Saving waits for Firestore acknowledgement; failed checkout preserves the cart. Repeated checkout taps share one pending write. Firebase restores sign-in after app restart and the app subscribes to that user's history.

Rules restrict private account records to the owner and deny unknown collections. Published shops/products are readable by customers, including guests; only the owning vendor can edit them. Hidden shops and products remain owner-only. Profile documents reject passwords and role fields. Client order/journey records are append-only. Vendors cannot access private customer history or mutate fulfillment documents directly. The new callable backend validates inventory/prices, reserves stock, mirrors order status, and assigns partners transactionally. Deploy it with the prepared rules/indexes before enabling live fulfillment; legacy client preview totals remain untrusted.

Logout clears account-scoped navigation, cart, profile, location, orders and journeys from app state. Cloud history remains for the next sign-in. Firestore disk persistence is disabled to avoid persisting private documents on shared devices. Signed-in preferences are separate from device-local guest preferences. Guest journeys/orders are session-only; guest checklist and notification settings use `shared_preferences`. Notification delivery is not implemented.

## Local Firebase tests and Android simulator

Use Node.js, the Firebase CLI and **Java 21+**. Tests use the isolated `demo-route-rescue` emulator project and do not create production accounts/data.

```sh
npm ci
npm run test:rules
```

The security suite checks cross-account/anonymous denial, invalid writes, immutable history, and Auth emulator signup/sign-out/sign-in with restored Firestore history.

Keep the emulators running in one terminal:

```sh
firebase emulators:start --only auth,firestore --project demo-route-rescue
```

Run the Android app in another:

```sh
flutter run -d emulator-5554 --dart-define-from-file=config/firebase.emulator.json
```

Android's `10.0.2.2` points to the host computer. For web, also pass `--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1`. Emulator routing is debug-only and uses a separate Firebase app instance. Emulator data is temporary unless explicitly exported and remains separate from `arjunlayover`.

On this Mac, Android Studio includes Java 21:

```sh
export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
export PATH="$JAVA_HOME/bin:$PATH"
```

## App workflow

1. Sign up, log in, or continue as guest.
2. On Home, open **Delivery place**. Type any address in **Delivery place / address**, add an optional landmark, then tap **Pin delivery location** and choose the exact point on the map (or use your current location). Suggested bus/train stops fill the address and pin together. Add the journey details and save. Changing the address requires confirming a new pin. The address, coordinates and instructions appear in checkout and are retained in order/travel history using the existing Firestore schema.
3. Search medicine names, food, categories, shops, strengths/forms or aliases such as ORS. Open vendors with matching stock appear before sold-out matches and closed vendors.
4. Add essentials, review the bag and confirm a cash-on-delivery order when signed in and the backend is deployed, or a local preview when browsing as a guest. A cart contains one vendor's items.
5. View Orders, edit your name, view travel history and update preferences in Profile.

### Reading and appearance

Use the accessibility icon beside the home-screen cart to open **Reading & appearance**. It is also available on the welcome and sign-in screens. Choose the bundled OpenDyslexic regular/bold font, 100%/115%/130% text size, and original lime, blue/amber or high-contrast white-on-black colours. Text sizing adds to the device's own setting. Changes apply immediately across routes without clearing the cart; **Restore defaults** resets the choices.

These settings are saved locally, work offline, and remain available across sign-in and sign-out. They do not change the Firestore schema or rules. Availability and order progress use written labels and distinct icons as well as colour. Fonts are a personal reading preference; no universal readability benefit is assumed. The [OpenDyslexic source and SIL OFL license](https://github.com/antijingoist/opendyslexic) are recorded in `assets/fonts/`, and the license is available under About Here You Go → View licenses.

### Nearby shops and device location

Home and Explore share **Bus · within 7 km** and **Train · within 20 km** controls. All closer shops are included, even at the search center. The map shows the selected outer radius. The selected journey supplies the default mode, and saving a different journey resets the browsing mode. Home, Explore, product search and shop markers use the same unrounded straight-line distance filter. Available matching stock stays first, with distance breaking remaining ties. An empty area stays empty instead of showing distant shops.

Search centers on the captured device location, falling back to the saved delivery pin, then an explicitly labelled Kochi preview when neither is available. Both screens display the search source and coordinates, with **Use my location / Refresh location**, **Use delivery pin**, and **Change delivery location** controls as applicable. Explore also has a crosshair that centers the map. Startup refreshes GPS only when location permission is already granted. Device location and delivery destination have separate markers. Geolocator requests the best available accuracy with a 20-second timeout. Explore shows reported accuracy, capture time, approximate-permission guidance and an accuracy circle. No continuous or background tracking runs. Permission failures, disabled GPS and timeouts have recovery actions. Fixes older than two minutes at acquisition are rejected. After a failed refresh, a previous fix remains visibly timestamped; denied permissions or disabled GPS clear it.

`LocationResult` exposes coordinates, `accuracyMeters`, `capturedAt`, `approximate` and `isMocked` for future integration. These device readings are held in account-scoped memory and cleared on logout. Confirmed delivery coordinates remain in `journey.pickup.latitude` / `longitude` on saved journeys and orders for a later courier handoff. No Firestore rule changes or courier tracking writes are introduced. The [Geolocator package documentation](https://pub.dev/packages/geolocator/versions/14.0.2) describes native accuracy and permission behavior.

Production inventory comes from published vendor records, with real-time price/stock changes and expired products excluded. New shops and products appear in an already-open customer app when within range; moving or hiding them updates the results. Medicine details and shop pins are vendor-supplied; registration does not confer a verified-pharmacy badge. Distance uses the shop's confirmed map pin, not its typed address: vendors must confirm their actual entrance. Distances are straight-line, not driving distance or guaranteed delivery coverage. Local sample inventory is retained only for isolated tests. A failed production catalog connection displays an error instead of substituting sample stock, and recovered catalog streams resubscribe to inventory.

The catalog queries a conservative 21 km bounding box and applies exact distance checks locally. Near the dateline or poles it falls back to a latitude band. Queries cap at 200 shops and display a warning when that cap is reached. A larger rollout needs pagination/geohash queries and capacity monitoring. See the official [Firestore range-query documentation](https://firebase.google.com/docs/firestore/query-data/multiple-range-fields).

### Order delivery map

Open an order and tap **View delivery map**. The full-screen map shows the catalog shop and the order's saved delivery pin with different icons/shapes. A draggable panel shows order progress, courier connection status, address, handover instructions, order items and the saved coordinates. Large reading settings use a normal scrollable layout. **Fit delivery route** frames the pins and any loaded route; **Show my location** requests device GPS without changing the destination or pretending that the customer is the courier.

**Show road route** asks before sending the two pin coordinates to the routing provider. It sends no name, order contents or customer GPS fix. A successful response draws road geometry and gives estimated driving distance/time; preparation, stops and live traffic are excluded. Dotted sections connect road endpoints to the exact pins. Failed requests leave the pins visible, display no invented route/arrival time, and offer retry. Route results stay in memory for the page lifetime; moving the map or receiving a courier update does not request another route.

The configurable OSRM-compatible endpoint defaults to the [FOSSGIS routing service](https://routing.openstreetmap.de/about.html), with attribution, a fix-the-map link, app identification, bounded road snapping and a shared limit of one request per 1.1 seconds **per app process**. Use `--dart-define=ROUTING_BASE_URL=https://your-osrm-service` for another compatible endpoint. The public endpoint is for light development use: before a public rollout, select a provider/hosting plan and enforce aggregate request limits and caching on a backend. Request/response parsing follows the [OSRM route API](https://project-osrm.org/docs/v5.24.0/api/#route-service). The live endpoint was checked using only fixed catalog sample coordinates and the public KSRTC bus stand; it returned a valid road route. Local tests use an in-memory routing fixture. The Android integration test uses those same public sample points and does not use user GPS or a personal address.

`CourierTrackingSource` is the integration boundary for delivery tracking. `FirebaseCourierTracking` now connects live orders to the assigned partner’s order-scoped Firestore position. It accepts order-scoped positions with timestamps and optional accuracy/name. Guest and legacy preview orders remain disconnected, so the app never invents a moving courier. The map rejects invalid, future and out-of-order readings, retains a visibly stale last position after interruption, and treats fixes older than 90 seconds as stale. Timers and subscriptions end when the screen closes. The prepared backend accepts location only from the assigned partner; the deployed rules limit reads to order participants. The backend still needs deployment after the billing blocker is resolved.

## Development

Open this project root in VS Code or Android Studio with Flutter/Dart extensions. Start an Android emulator and select it. Android and web are supported; no iOS/desktop scaffolds are included.

```sh
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
flutter test integration_test/customer_flow_test.dart -d emulator-5554
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/accessibility_test.dart -d emulator-5554
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/delivery_place_test.dart -d emulator-5554
# Native GPS integration test: use a known emulator coordinate, not a real device.
adb shell pm grant com.app android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant com.app android.permission.ACCESS_FINE_LOCATION
adb emu geo fix 76.29 9.85
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/nearby_location_test.dart -d emulator-5554
# Uses only the fixed sample shop and public bus-stop coordinates:
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/delivery_map_test.dart -d emulator-5554
# With the local Firebase emulators running:
flutter test integration_test/firebase_account_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.emulator.json
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/catalog_sync_test.dart -d emulator-5554 --dart-define=FIREBASE_USE_EMULATORS=true
```

`lib/data/firebase/` implements account, merchant and catalog repositories and serialization. Their interfaces in `lib/data/` provide testable boundaries. Providers subscribe to the current account and nearby catalog. `lib/data/mock_*` contains isolated test fixtures; shared theme/components are in `lib/core/` and `lib/widgets/`. `vendor_app/` shares these models and repositories through a local package dependency.

Developed with Flutter 3.41.1 / Dart 3.11.0, AGP 8.11.1, Gradle 8.14 and Java 17 bytecode. Keep both lockfiles. The geolocator/path-provider constraints retain toolchain compatibility. JavaScript test dependencies override gRPC to a patched compatible version.

Android declares internet and foreground coarse/fine location permissions. There is no background location polling. Map tiles use OpenStreetMap attribution and native caching; `--dart-define=MAP_TILE_URL=...` selects another provider. Review the [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) before a larger rollout.

## Verification — 11 October 2026

- `flutter analyze`: no issues.
- Customer Flutter suite: 64 tests passed. Coverage includes live catalog synchronization and recovery, startup failure without sample fallback, price/stock changes, archived products, inclusive bus/train radii, GPS restoration only with existing permission, road-route parsing/consent/retry, stale courier updates, delivery-map accessibility, GPS accuracy/stale-fix handling, map/list consistency, saved appearance choices, palette contrast, cart preservation, checkout at 320 px width with OpenDyslexic and combined 195% text scaling, account isolation, failed cloud writes and duplicate checkout prevention.
- Vendor Flutter suite: 4 tests passed, covering currency/expiry validation, medical product entry, account isolation and the shop form at 320 px with enlarged text.
- Android vendor/customer integration: passed native signup, medical shop registration, map pin, medicine publishing, separate guest customer discovery at 6.1 km, price/stock synchronization and hiding products/shops against local Firebase emulators. Screenshots: `vendor_app/screenshots/`.
- Android customer synchronization integration: passed with separate native vendor and guest customer Firebase clients. A shop/product published after the customer screen opened appeared at 0 km; price/stock edits, moving to 8 km (bus excluded, train included), moving beyond 20 km and back, and hiding/republishing all updated without restarting. Screenshot: `screenshots/customer-live-vendor-sync.png`. All test writes used the local emulator project.
- Updated customer release APK: native GPS on the emulator found the existing published shop at 0.1 km; medicine search displayed its live ₹15 price and 50-unit stock. Screenshots: `screenshots/customer-live-location.png` and `screenshots/customer-live-medicine-search.png`. This check was read-only against production.
- Vendor Android and web builds passed; both customer and vendor Android apps are installed on the emulator. Live catalog rules/indexes are deployed. Both location-query variants succeed, and anonymous reads of private vendor/customer paths are denied. The checks created no production accounts or inventory.
- Android delivery-map integration test: passed opening the map from an order, explicit routing consent, real OSRM road geometry between the fixed sample shop/public KSRTC stop, drive estimate, map tiles and absence of a fabricated courier. Screenshot: `screenshots/here-you-go-delivery-map-road-route.png`. The map tests also pass at 320 px with OpenDyslexic and 195% text scaling.
- Earlier Android GPS integration test: passed with native Geolocator at emulator coordinates 9.85, 76.29. The map marker, shop distances and tiles were visually checked. Historical screenshot `screenshots/here-you-go-nearby-gps.png` predates the removal of the bus/train minimum distances.
- Android accessibility integration test: passed font/size/theme changes, route navigation and restoring defaults on the Pixel 9a emulator. Screenshots are in `screenshots/accessibility-*.png`.
- Android delivery integration test: passed typing an address, confirming and editing its map pin, and retaining the address, coordinates and instructions through checkout. Street map tiles were also visually verified in the normal app.
- Firebase rules/Auth emulator suite: 13 tests passed, including private contact isolation, vendor ownership, medicine validation, public/hidden catalog queries, customer history protection, custom addresses and map pins.
- Android Firebase integration test on Pixel 9a: passed signup, profile update, preferences, order/journey storage and sign-in restoration using the actual native SDKs.
- Web build: passed.
- Android APK build: passed. Google Maven full downloads stalled on this connection; a temporary local bridge fetched the same official artifacts with byte-range requests. The bridge is outside the repository and no mirror was added to project configuration.
- Live Firebase signup/sign-in: passed after Email/Password was enabled; the temporary account was removed.
- Live Firestore rules, after the project owner published them: own-profile read allowed (the new account correctly has no document yet); cross-account and anonymous reads denied. Temporary Auth accounts were removed. No live Firestore test documents were created.
# hereyou-go
