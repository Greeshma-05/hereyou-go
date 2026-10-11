# Firebase integration: arjunlayover

The supplied `google-services.json` is installed unchanged in `android/app/google-services.json`. It registers Android application **`com.app`** in Firebase project **`arjunlayover`**. At the user's request to use this file, the Android application ID was changed to `com.app`. The source/Kotlin namespace remains `com.routerescue.routerescue_partner`; these settings do not need to be renamed together.

`com.app` was not installed on `emulator-5554` before installation. The earlier package `com.routerescue.routerescue_partner` is a separate installation; its data was not deleted. The new package starts with its own onboarding preferences.

Both customer and partner apps can use the same Firebase project. **They must have distinct Android application IDs to be installed side by side.** If the actual customer app also uses `com.app`, a second Android registration is necessary for one app. Do not install this APK over a customer build with the same ID.

## Implemented

- Google services Gradle plugin **4.5.0** is declared in `android/build.gradle.kts` and applied in the app module.
- Firebase BoM **35.0.0** is applied to the app and FlutterFire native dependencies.
- Flutter SDKs: `firebase_core 4.15.0`, `firebase_auth 6.7.0`, `cloud_firestore 6.10.0`.
- Android startup initializes Firebase from Google services resources and checks the project is `arjunlayover`. Initialization failure keeps the offline demo accessible. Other platforms remain demo-only until separately configured.
- Login and Create account call real Firebase email/password authentication, with loading, sanitized errors and no password logging/storage. Signup validates name, email, password length and confirmation. Login never creates an account implicitly.
- Signup sets the Auth display name and creates `/users/<new uid>` with the supplied profile schema and server timestamps, only if that profile is missing. Existing customer profiles are preserved. A profile setup failure is reported separately from successful account creation, so the user can still log in.
- Forgot password requests a Firebase reset email for the entered address. Its confirmation does not reveal whether an account exists. No reset emails are sent by automated verification.
- A real sign-in/signup opens Mission Control directly, with the existing Deliveries, RoutePulse, Earnings and Profile tabs. The signed-in name/email are retained separately from delivery data. A **Sample deliveries** banner identifies the in-memory requests, missions, SafePass, notifications and earnings. This does not grant a server-side delivery role or access to customer orders.
- **Profile > Account details** reads only `/users/<signed-in uid>` from the server, with missing-profile, permission and network error handling. Back returns to the selected Profile tab without signing out. An unavailable profile never blocks the delivery tools.
- **Profile > Sign out** clears Firebase authentication before discarding the local session. Failed sign-out retains the session; an active delivery must be completed first. Navigation is disabled during sign-out. Entering Demo Mode also signs out retained Firebase authentication. The SDK manages token persistence; startup still requires explicit login or demo entry.
- Demo orders, earnings and six-digit SafePass codes remain in memory and are never uploaded.
- `customer.firestore.rules` preserves the supplied rules as a reference. No rules, roles or backend functions have been deployed. The authentication smoke check creates and deletes its own temporary account when explicitly requested.

## Run and sign in

```powershell
$flutter = 'C:\Users\arjun\Downloads\flutter_windows_3.47.4-stable\flutter\bin\flutter.bat'
& $flutter pub get
& $flutter run -d emulator-5554
```

Tap **Create account**, enter your name, email and matching passwords, then **Sign up**. Already registered in the customer app's `arjunlayover` project? Use **Login** with that same email/password instead. If you forgot the password, enter your email and tap **Forgot password?**. The JSON connects the app to Firebase; it does not supply a user's login credentials. Do not send passwords in chat or store them in the repository.

Signup has no Demo Mode card or demo entry button. Successful signup/login goes straight to the full application shell. Guest Demo Mode remains available on Login. All delivery actions currently use sample data, for signed-in and guest sessions alike.

The live authentication smoke check confirmed Email/Password signup and login are enabled in `arjunlayover`. An account without a saved `/users/{uid}` profile can still authenticate; the account screen explains that the profile is missing. Rules and permissions for live delivery dispatch remain separate from account authentication.

Demo Mode requires no credentials. Firebase sign-in does not grant a delivery role by itself.

For future configuration files, this helper checks the project and current Gradle application ID before copying:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\configure-firebase.ps1 -ConfigPath 'C:\path\to\google-services.json'
```

Add `-ValidateOnly` to validate without copying. Do not manually rewrite identifiers inside downloaded Firebase configuration files.

## Why customer orders are not synchronized yet

The supplied rules are for customer preview records. Adding Firebase SDKs does not override them:

| Current rule | Effect on delivery partners |
| --- | --- |
| `/users/{uid}/orders/{orderId}` is readable only by that UID | A partner cannot query another customer's orders. |
| Only `isPreview: true`, `status: 'placed'` can be created | These are previews, not validated dispatch commands. |
| Order updates/deletes are forbidden | Acceptance, pickup and completion cannot change these records. |
| All other paths are denied | Partner profiles, offers, assignments and earnings have no authorized storage contract. |
| Customer preview code is four digits and client-written | It is separate from six-digit demo SafePass and is not trusted handover verification. |
| Item contents and price sums are not fully validated | A trusted service must validate products, stock and totals before dispatch. |

The nearby `user-app/user_app` and `ft/testft` folders contain Flutter starter projects. The actual customer app source and its order/item serialization are still needed for compatible shared delivery screens.

## Shared workflow still required

1. Provision partner roles through a trusted administrator/server. Clients cannot grant themselves a delivery role.
2. Preserve current previews. Validate real submissions on the server, or explicitly create sandbox jobs for a shared demo. Do not silently dispatch every preview as a real order.
3. Publish a minimal offer feed for eligible partners. Reveal necessary customer/handover details only to an authorized assignee.
4. Accept offers transactionally: one assignee per job and one active job per partner. Store a fulfillment record keyed by the customer/order identity.
5. Both apps subscribe to that record. Customer access is scoped to the owner and partner access to the assignee. Existing immutable previews need not be weakened.
6. Validate stage transitions and handover on a trusted server, then record earnings once. Partners cannot choose their own reward or bypass verification.
7. Merge and emulator-test rules with the actual customer's rules, then publish and verify both applications against the same sample order.

This contract is documentation, not a deployed dispatch backend. There is no permissive replacement rule or automatic deployment command in this project. Sharing live customer orders and delivery updates is **not yet implemented**.

## Verification

Dependency resolution, Dart formatting and Flutter analysis succeeded. All **63 Flutter tests passed**, including signup without a demo panel, direct signed-in access to all tabs, real identity with sample delivery data, the complete signed-in delivery/SafePass/earnings/history journey, safe logout and account isolation, profile retries, password recovery, and small-screen keyboard layouts. The configuration helper rejected a package mismatch and accepted/copied the original file after the application ID was aligned. The copied file's SHA-256 matches the supplied file.

The configured Android x64 debug build succeeded. The Google services task generated resources for project `arjunlayover` and the supplied Firebase app ID. The APK was installed as `com.app` and launched on `emulator-5554`. Native logs reported `FirebaseApp initialization successful`; onboarding led to the configured Firebase login screen, and Try Demo Mode opened the existing dashboard and five-tab navigation.

The live Auth REST smoke check succeeded: signup, login with the created credentials, incorrect-password rejection, and deletion of the temporary account. The updated native Android check verified signup without a demo panel, Firebase Login directly into Mission Control with the signed-in name, all four other tabs, and sign-out back to Login. All temporary Auth accounts were deleted; these checks created no Firestore documents or email messages. Profile writes and reset email delivery were not live-tested; their UI states are covered by Flutter tests. Cross-app delivery synchronization remains unimplemented.

To repeat the check with Node.js 18 or newer:

```powershell
# Read-only check using nonexistent credentials:
node tool/check-firebase-auth.cjs
# Creates and then deletes its own temporary Auth account:
node tool/check-firebase-auth.cjs --create-test-account
```

Built-in Kotlin is enabled for Flutter 3.47 / AGP 9.1. The remaining Firebase/Kotlin warning comes from Flutter's build-script text scanner detecting the plugins' conditional legacy-Kotlin declarations, even when that branch is disabled. The configured Android build succeeds; no SDK or dependency-cache files were modified to suppress the warning.

Official references: [Flutter setup](https://firebase.google.com/docs/flutter/setup), [Android setup and registration](https://firebase.google.com/docs/android/setup), [Firestore rule conditions](https://firebase.google.com/docs/firestore/security/rules-conditions).
