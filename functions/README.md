# Shared fulfillment backend

The order service runs as a standalone Node.js web service on Render (or another Node host). All three Flutter apps keep Firebase Authentication and the same Firestore database, `arjunlayover`, on Spark. No Firebase billing change or Cloud Functions deployment is needed for this route.

**Live:** https://here-you-go-orders.onrender.com/fulfillment, Render Free in Singapore, service `srv-db5cu55ckfvc739p7ra0`. Deployed and verified on 11 October 2026. A live temporary test completed customer checkout → vendor visibility/acceptance → 5 km partner discovery/assignment → pickup → verified handover → customer status sync; all temporary documents and Auth accounts were removed. Firestore rules and fulfillment indexes are deployed; billing remains disabled.

All three apps default to this deployed endpoint. `FULFILLMENT_URL` remains a build-time override for other deployments; emulator builds never fall back to production. Old APKs must be updated.

## Deploy to Render Free

1. Deploy this repository with the root `render.yaml` Blueprint, choosing the free plan. The service runs `npm ci --omit=dev` and `npm start` inside `functions/` on Node 22. No paid database is created.
2. Provision a dedicated Google service account in `arjunlayover` with only the project role `roles/datastore.user`. ID token verification uses Firebase public signing certificates; this service does not need Firebase Authentication administrator access. Do not use an Owner/Editor account or a user's CLI login as the hosting credential.
3. Store that account's JSON key **only in Render's Secret Files**, filename `firebase-service-account.json`. `GOOGLE_APPLICATION_CREDENTIALS` points to `/etc/secrets/firebase-service-account.json`, and `GOOGLE_CLOUD_PROJECT` is `arjunlayover`. Never commit the key, paste it into chat, or package it in an APK. Production startup rejects emulator variables, absent credentials and a mismatched credential project.
4. Deploy. Check `https://<actual-service-name>.onrender.com/healthz` returns `{"status":"ok"}`. An unauthenticated POST of `{"data":{"action":"nearby"}}` to `/fulfillment` must return HTTP 401. Health alone does not prove the service account has Firestore access; run an authenticated test order before release.
5. Build **all three apps** from the repository root using the actual service URL:

```sh
python3 scripts/build_connected_apks.py https://<actual-service-name>.onrender.com/fulfillment
```

The script checks the endpoint, builds universal release APKs with the same `FULFILLMENT_URL`, and writes them to `releases/connected/`. Existing release signing configuration is retained. Distribute all three updated APKs together. Customer previews already saved in history are not purchases and must not be copied into the vendor's order queue; signed-in customers must place a fresh live order.

Render's free instance sleeps after 15 minutes without traffic and can take about a minute to wake. Clients wait up to 120 seconds and preserve the checkout reference and cart on failure so a retry cannot reserve stock twice. Free hosting and Firebase Spark quotas still apply. See [Render free service limits](https://render.com/docs/free) and [secret-file setup](https://render.com/docs/configure-environment-variables#secret-files).

`index.js` retains the callable wrapper so the Firebase client SDK sends and verifies sign-in tokens in the same way on either host. `server.js` serves that wrapper via Express; it never invokes the unauthenticated `.run()` helper. All database mutations and the 5 km distance checks remain server-side. Rules still deny direct client writes to fulfillment records.

## Local standalone test

```sh
npm ci
npm ci --prefix functions
npm run test:standalone
```

This starts isolated Auth/Firestore emulators and tests the actual standalone HTTP server with separate authenticated customer, vendor and courier clients. No Cloud Functions emulator or production credentials are required. To run the Android integration test, start the Auth/Firestore emulators using `firebase.test.json`, run the server with `NODE_ENV=test`, `GOOGLE_CLOUD_PROJECT=demo-route-rescue`, `GCLOUD_PROJECT=demo-route-rescue`, `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9199`, `FIRESTORE_EMULATOR_HOST=127.0.0.1:8180`, and `PORT=10000`. Then run:

```sh
cd delivery_app
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/fulfillment_flow_test.dart -d emulator-5554 --dart-define-from-file=../config/firebase.integration.json --dart-define=FULFILLMENT_URL=http://10.0.2.2:10000/fulfillment
```

Local HTTP is permitted only in debug emulator builds. Release builds require HTTPS.

## API

All actions require Firebase Authentication. The server derives the UID from the verified callable token, never from request fields.

| Action | Role and behavior |
| --- | --- |
| `createOrder` | Customer; validates live shop/products, delivery area, expected prices and total; reserves stock and creates both records atomically. A repeated order reference returns the existing order without reserving stock twice. |
| `registerCourier` | Legacy callable registration; saves validated name, phone and vehicle. Current delivery clients use a rules-validated Firestore transaction for contact details instead. |
| `presence` | Registered partner; publishes availability, a fresh location and its server-computed `locationGeohash`, updating only the assigned order's tracking record. |
| `nearby` | Online available partner; geohash bounds plus exact distance filter return redacted pickups within 5 km. Customer identities, delivery addresses and codes are excluded. |
| `claim` | Online partner; transaction checks fresh location, range, availability and single-active-order constraints. Self-delivery of one's own customer/vendor order is denied. |
| `nearbyCouriers` | Owning vendor with an accepted/preparing/ready unassigned order; returns available partners within 5 km of the saved pickup pin, nearest first. Only ID, name, vehicle and distance are exposed. Filters stale GPS, offline/busy partners and the order's vendor/customer accounts. |
| `assignCourier` | Owning vendor; transaction rechecks order, partner availability and exact 5 km distance. Updates the order, private customer mirror, courier active assignment and order tracking atomically. Retrying the same active assignment is idempotent. |
| `transition` | Owning vendor advances `placed → confirmed → preparing → ready`; assigned courier advances `ready → pickedUp → handedOver`. Handover needs the customer's private code. Five incorrect attempts lock verification for ten minutes. Cancellation restores stock and releases the courier. |

Assignment is independent of preparation status, so a vendor can assign a courier as soon as an order is accepted. Self-claiming still starts when the order is preparing/ready. The customer mirror carries `courierId`, `courierName` and `assignmentSource` without overwriting the vendor's progress. Vendor assignments and courier self-claims use the same transaction rules; simultaneous attempts cannot double-assign an order or a courier.

The courier discovery index is `(online, activeOrderId, locationGeohash)` in the root `firestore.indexes.json`. Each fresh online presence updates the geohash; existing courier profiles need no manual migration. The index is deployed. The standalone service exposes the same actions once hosting is configured.

## Firestore data

| Path | Access |
| --- | --- |
| `orders/{reference}` | Server writes; ordering customer, owning vendor and assigned partner read only their orders. Includes immutable item/price/pickup/destination snapshots. No handover code. |
| `users/{customerUid}/orders/{reference}` | Customer-only mirror, including the server-generated handover code. Existing schema-1 preview history is still readable. |
| `orderSecrets/{reference}` | Server-only code and verification-attempt counter; deleted on completion/cancellation. |
| `couriers/{uid}` | Owner-only reads. Owners may create an offline, unassigned profile and edit only name, phone, vehicle and server `updatedAt`. Location, availability, assignment and other operational fields remain server-only; clients cannot delete profiles. |
| `orderTracking/{reference}` | Server-only writes; order participants read. Removed on completion/cancellation or going offline. |

Existing public shop/product queries and private account/journey/preferences rules remain in place. New orders have `schemaVersion: 2`, `isPreview: false`, and `paymentMethod: cashOnDelivery`. Client-supplied prices and totals are never authoritative. Products requiring a prescription are rejected until verification is implemented.

## Validation

```sh
npm run test:fulfillment
```

The isolated suite covers authenticated callable requests from separate app instances and Firestore access rules. Use Java 21+. On this Mac, Java 21 is bundled at `/Applications/Android Studio.app/Contents/jbr/Contents/Home`; set `JAVA_HOME` and prepend its `bin` directory to `PATH` when necessary. Deployment uses Node 22; local Firebase CLI may report a different installed Node version.
