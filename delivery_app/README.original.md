# RouteRescue Partner

Every delivery moves a journey forward.

A cinematic dark-and-lime Flutter Android demo for route-aware essentials delivery. Built incrementally on the existing splash, onboarding, login and navigation architecture. The redesign follows the supplied written visual specification; no reference image or customer-app assets were available in this workspace.

Firebase account integration uses the supplied **arjunlayover** registration. To use that JSON unchanged, the Android application ID is **`com.app`**; the Kotlin namespace stays `com.routerescue.routerescue_partner`. Real Firebase email signup, login, password recovery and an account-owned profile are wired separately from Demo Mode. Tap **Create account** to register, or use **Login** for an existing account in the same Firebase project. Customer-to-partner order synchronization still requires a shared fulfillment backend and partner access rules. See [Firebase configuration and shared workflow requirements](firebase/README.md).

Signup and login open **Mission Control directly**, with access to all existing delivery features and the five-tab navigation. Signup has no Demo Mode section. Signed-in sessions show the account's name/email and a **Sample deliveries** banner because orders, missions and earnings remain simulated. Saved Firebase profile details are available under **Profile > Account details**; **Profile > Sign out** ends the authenticated session. Guest Demo Mode is still available on Login.

## Launch

Workstation: Flutter 3.47.4, Dart 3.13.3, Android emulator `Pixel_9` (`emulator-5554`). Flutter is not on this terminal's PATH.

```powershell
Set-Location 'C:\Users\arjun\OneDrive\Desktop\dele'
$flutter = 'C:\Users\arjun\Downloads\flutter_windows_3.47.4-stable\flutter\bin\flutter.bat'
& $flutter pub get
# Only if the emulator is not already running:
& $flutter emulators --launch Pixel_9
& $flutter run -d emulator-5554
```

With Flutter on PATH: `flutter pub get`, then `flutter run -d emulator-5554`.

VS Code now has workspace Flutter SDK and terminal PATH/JAVA_HOME settings in `.vscode/settings.json`. Open a **new terminal** in this workspace to use `flutter run -d emulator-5554` directly. Existing terminals keep their previous environment. The current Firebase app is installed as `com.app`; the older `com.routerescue.routerescue_partner` installation is separate.

Android uses built-in Kotlin with the current Flutter/AGP versions. The Gradle launchers enable the native access needed by the bundled Java 25 runtime, resolving its restricted-method warning. A non-blocking Firebase compatibility warning remains in Flutter's text-based Kotlin checker; see [integration verification](firebase/README.md#verification).

## Recommended presentation

1. Complete onboarding, or tap Skip. Returning launches go from splash to Login.
2. Tap **Try Demo Mode**, without entering credentials.
3. On **Control**, turn **Availability** on. The banner and Profile update immediately.
4. Open **Deliveries → RR-2401 → View mission**.
5. Inspect Ananya Rao's **1 snack box + 2 water bottles**, pickup at **Platform Pantry, Kengeri**, handover at **Bidadi station**, and **₹120** simulated reward.
6. Review **EXCELLENT FIT**: 0.8 km to pickup, 0.6 km detour, 3 min wait, 35 min window, 13 min estimated effort.
7. Tap **Accept request**. One active mission is allowed.
8. Open **RoutePulse**. Tap a parcel marker or order chip to inspect an opportunity. The offline diagram works without internet; street tiles are optional.
9. Return to **Deliveries → Continue active mission → Start mission**.
10. **Confirm arrival at vendor**, check both package items, then **Confirm package collection**.
11. Tap **Head to handover → Confirm arrival at handover → Open SafePass**.
12. Try an incorrect code, then enter **246810** and tap **Verify handover**.
13. Tap **Return to active mission → Complete delivery**. A success screen appears.
14. **Return to your journey**, then check **Earnings**: ₹120 today, one completed delivery, ₹120 average reward.
15. Open **View delivery history** and find RR-2401 exactly once.
16. Switch tabs, inspect Notifications, and open Profile. The same state is shared everywhere.
17. Tap **Log out of demo**. Onboarding stays completed. Re-enter Demo Mode for a fresh, offline presentation.

The other deterministic requests are RR-2402 (GOOD FIT, ₹165, demo code 135790), RR-2403 (TIGHT TIMING, ₹140, code 112233), and RR-2404 (ROUTE MISMATCH, ₹220, code 445566). RR-2399 is a cancelled sample with no earnings. The demo clock starts at **11 October 2026, 09:00** and advances by one minute per order action; it does not claim live deadlines.

## Implemented features

- Dark Material 3 theme, ivory-white type, lime actions, olive surfaces, glass panels, restrained ambient introduction, and local route illustrations.
- Preserved animated splash, accessible three-page onboarding and persisted completion preference.
- Firebase signup/login and password recovery with validation, password visibility, keyboard handling, loading and error feedback. Existing customer accounts in the same Firebase project can sign in.
- Mission Control with avatar, notification badge, online/offline control, journey preview, counters, recommendation and Roo tips.
- Searchable All/New/Accepted requests, detailed items and locations, rewards, StopFit, acceptance and rejection.
- RoutePulse with pan/zoom, selected order information, pickup/opportunity and handover markers, route summary, stop list and an opportunity bottom sheet.
- Eight-stage active delivery, pickup item checklist, contextual actions, SafePass and delivery success.
- Derived daily/last-seven-day demo earnings, average reward, seven-day chart and recent rewards.
- Filterable completed/rejected/cancelled history.
- Local notification inbox, read states, unread badge, mark-all-read and contextual navigation.
- Profile, availability, local notification preference, practical device haptics, About and guarded logout.
- One floating navigation bar: Control, Deliveries, RoutePulse, Earnings, Profile. Details use the existing Navigator and preserve the selected tab and scroll state.
- Code-drawn Roo character for guidance and success; no remote illustrations, animation service, or image API.

## State and integrity

`PartnerRepository` is the replaceable state contract. `MockPartnerRepository` is the current in-memory implementation, exposed through the existing `SessionScope` using Flutter's `InheritedNotifier`. No additional state-management package is used.

- Offline partners can browse but cannot accept.
- Only one order can be active. Repeated acceptance and acceptance from a rejected/stale screen fail.
- Every progression command checks its expected status; old double-tap callbacks cannot advance a new stage.
- Pickup and handover stages cannot be skipped. SafePass must succeed before completion.
- Verification is tied to the selected order and becomes unusable after verification/completion within this session.
- Completion can happen only once. History timestamps are keyed by order ID. Earnings are calculated from completed orders, not appended to a second transaction store.
- Notifications are generated by actual demo actions; turning notifications off suppresses future local notices.
- Going offline does not remove an active mission. Logout is disabled while a mission is active.
- Logout or a process restart creates a fresh demo repository. Orders, earnings, history and profile preferences are not persisted. Only the onboarding boolean is saved with shared_preferences.

SafePass is **not a secure OTP system**. The code is intentionally displayed in the app for rehearsals. Production code generation/delivery, expiry, rate limiting, replay protection, authorization and verification require a trusted backend.

## StopFit demo rules

`StopFitService` calculates:

```text
estimated minutes = ceil((pickup km + detour km) × 3) + waiting minutes + 5
margin minutes = available minutes − estimated minutes
```

This assumes a fixed 20 km/h for pickup plus detour and five minutes of handling. Classification precedence:

| Result | Rule |
| --- | --- |
| ROUTE MISMATCH | Different corridor, or detour greater than 6 km |
| TIGHT TIMING | Remaining margin less than 8 minutes |
| EXCELLENT FIT | Detour ≤ 1.5 km, pickup ≤ 2 km, and margin ≥ 15 minutes |
| GOOD FIT | Other matching requests |

Results and explanations are derived from each order's properties. They are demo estimates, not traffic-aware navigation, a schedule guarantee or a production feasibility algorithm.

## RoutePulse and connectivity

The default is a locally drawn, interactive **offline diagram**, explicitly labeled not to scale. This keeps the delivery demo usable without networking.

The Street tiles switch enables OpenStreetMap using `flutter_map 8.3.2` and `latlong2 0.9.1`. The Android manifest requests internet access for optional tiles. No API key, device location permission or paid map API is needed.

- A lime polyline links seeded stop coordinates; it is a simulated route, not calculated road routing.
- Marker selection opens an order panel; order chips provide another way to select nearby/overlapping markers.
- Tile errors or no successful tile within eight seconds return to the offline diagram with a clear message.
- Missing coordinates show a notice and preserve stop names/details; unusable map coordinates do not crash the screen.
- OSM attribution is visible while street tiles are enabled; the client identifies itself with the application's package name. No bulk tile download or offline tile prefetch is implemented.
- No real GPS, traffic, live bus/train position, precise directions or background tracking is claimed.

Implementation references: [flutter_map tile layer](https://docs.fleaflet.dev/layers/tile-layer), [flutter_map package](https://pub.dev/packages/flutter_map), [OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/). Public tile availability is outside the app's control; use the offline diagram for a dependable presentation.

## Design and files

Palette: background `#080906`, secondary `#11130D`, cards `#191B14`, lime `#D9FF43`, secondary lime `#B9DB36`, primary text `#F7F8F1`, secondary text `#A3A697`.

Updated existing files include `app.dart`, theme files, `AppEntry`, `AppShell`, `SessionScope`, `DemoSession`, `DeliveryStatus`, login, all original tab screens, shared brand/illustration/status widgets, Android colors/manifest, pubspec and tests. The existing entry forms and preference service remain in place.

Added functional areas:

```text
lib/
  data/demo_data.dart
  models/
    delivery_request.dart
    delivery_partner.dart
    delivery_history_entry.dart
    route_stop.dart
    stop_fit_result.dart
    partner_notification.dart
  services/
    partner_repository.dart
    mock_partner_repository.dart
    stop_fit_service.dart
  core/utils/
    demo_action.dart
    demo_format.dart
    partner_navigation.dart
  screens/
    requests/request_details_screen.dart
    map/route_pulse_screen.dart
    mission/safe_pass_screen.dart
    mission/delivery_success_screen.dart
    history/history_screen.dart
    notifications/notifications_screen.dart
  widgets/
    cinematic_background.dart
    circle_action.dart
    glass_panel.dart
    floating_partner_navigation.dart
    route_canvas.dart
    route_map.dart
    route_info_row.dart
    request_card.dart
    stop_fit_badge.dart
    stat_card.dart
    mission_progress.dart
    earnings_chart.dart
    roo_tip.dart
```

Direct runtime dependencies: Flutter, shared_preferences, flutter_map, latlong2, firebase_core, firebase_auth and cloud_firestore. No image service, additional state-management plugin or payment package.

## Validation

Run:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --target-platform android-x64
```

Each implementation phase A–H passed static analysis and an Android x64 debug build before continuing. Dependency resolution and Dart formatting completed successfully. The complete Flutter test suite now passes **63 tests**, including direct signup/login access to the feature shell, signup without a demo panel, password recovery, account isolation, safe logout, full signed-in and guest delivery journeys, exactly-once earnings and invalid/reused SafePass codes.

The final Android debug APK was installed and launched on `Pixel_9` / `emulator-5554`. Emulator checks covered Demo Mode, availability, the dashboard, delivery requests, retained bottom navigation, the corrected RoutePulse labels and handover marker, and a parcel marker opening its mission panel. Optional street tiles were unavailable during this emulator session; the app displayed its fallback message and kept the offline route and mission details usable. Successful network tile loading is not claimed. The full completion/earnings/logout sequence was verified by Flutter widget and repository tests rather than a complete manual device walkthrough.

Android's UI automation bridge intermittently returned an empty accessibility tree during startup; screenshots and subsequent UI reads confirmed the app was running. This affected the inspection tool, not the automated Flutter test results.

Cold debug startup on this emulator took several tens of seconds after APK installation. Open the app before starting a presentation. Release-mode performance has not been profiled.

Test coverage includes first/returning launches, storage failure recovery, login validation/loading/password visibility, repeat login/logout, retained tabs/scroll and Android Back; StopFit classifications, offline/duplicate/stale acceptance, invalid transitions, incorrect/order-specific/reused SafePass codes, duplicate completion, exact earnings, notification settings/read state; search/rejection/history filters; offline marker selection, tile-error fallback and missing coordinates.

The full delivery journey is exercised at 390×844 with normal text, 320×568 with 2× text, and 640×360 with 2× text, including the SafePass keyboard. Existing entry/shell layouts retain coverage at 320×568, 360×640, 412×915 and 640×360 with 1×/2× text. Accessibility guidelines check labels, text contrast and complete Android touch targets in a tall viewport to avoid measuring partially clipped controls. Physical-device and manual TalkBack verification are not claimed.

## Future integrations and limits

All partner data, availability, mission actions, StopFit, handover codes, rewards, ratings, notifications and journey progress are local demo behavior. Online status is not synchronized to a server.

Firebase email signup/login, password recovery and an account-owned Firestore profile are implemented using the supplied Android configuration. Live Auth signup/login and wrong-password rejection passed a temporary-account REST check; that account was deleted. Profile writes and reset email delivery were not live-tested. Shared dispatch, durable delivery storage, GPS/location permissions, traffic/transit APIs, route calculation, trusted handover verification, push notifications and real payouts remain future integrations. Sound preferences are not exposed because no sound feature is implemented. Release signing still uses the Flutter template's debug configuration; production release and ARM-device validation are outside this demo verification.
