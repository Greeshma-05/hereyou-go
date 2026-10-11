import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/core/utils/formatters.dart';
import 'package:route_rescue/core/constants/demo_config.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:route_rescue/models/accessibility_settings.dart';
import 'package:route_rescue/widgets/common.dart';
import 'package:route_rescue/widgets/fulfillment_order_card.dart';
import 'package:route_rescue/widgets/map_attribution.dart';
import 'delivery_state.dart';
import 'package:route_rescue/services/location_service.dart';

class DeliveryApp extends StatefulWidget {
  const DeliveryApp({
    super.key,
    required this.auth,
    required this.repository,
    this.localTesting = false,
    this.locationService,
  });
  final FirebaseAuth auth;
  final FulfillmentRepository repository;
  final bool localTesting;
  final LocationService? locationService;
  @override
  State<DeliveryApp> createState() => _DeliveryAppState();
}

class _DeliveryAppState extends State<DeliveryApp> {
  AppColorTheme colorTheme = AppColorTheme.lime;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Here You Go Delivery',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(colorTheme: colorTheme),
    home: StreamBuilder<User?>(
      stream: widget.auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingView(message: 'Restoring your account…'),
          );
        }
        if (snapshot.data == null) return DeliveryAuth(auth: widget.auth);
        return DeliveryHome(
          key: ValueKey(snapshot.data!.uid),
          user: snapshot.data!,
          auth: widget.auth,
          repository: widget.repository,
          localTesting: widget.localTesting,
          locationService: widget.locationService,
          onTheme: () => setState(
            () => colorTheme = AppColorTheme
                .values[(colorTheme.index + 1) % AppColorTheme.values.length],
          ),
        );
      },
    ),
  );
}

class DeliveryAuth extends StatefulWidget {
  const DeliveryAuth({super.key, required this.auth});
  final FirebaseAuth auth;
  @override
  State<DeliveryAuth> createState() => _DeliveryAuthState();
}

class _DeliveryAuthState extends State<DeliveryAuth> {
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false, showPassword = false;
  String? error;
  Future<void> submit({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (reset) {
        await widget.auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) {
          setState(
            () => error =
                'If this email has an account, a reset link will arrive shortly.',
          );
        }
      } else if (register) {
        await widget.auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await widget.auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error = switch (e.code) {
            'email-already-in-use' =>
              'This account already exists. Log in with your customer or vendor password.',
            'weak-password' => 'Use a password with at least 8 characters.',
            'invalid-email' => 'Enter a valid email address.',
            'network-request-failed' =>
              'Check your internet connection and try again.',
            'too-many-requests' =>
              'Too many attempts. Please wait and try again.',
            _ => 'Could not sign in. Check your email and password.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const StatusBadge(text: 'HERE YOU GO · DELIVERY'),
            const SizedBox(height: 28),
            Icon(
              Icons.delivery_dining,
              size: 72,
              color: AppTheme.colors(context).accent,
            ),
            const SizedBox(height: 20),
            Text(
              'Every delivery.\nA journey forward.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick up nearby orders, keep travelers updated, and complete each handover with confidence.',
            ),
            const SizedBox(height: 28),
            Text(
              register ? 'Create your partner account' : 'Welcome back',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: !showPassword,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: 'Show or hide password',
                  onPressed: () => setState(() => showPassword = !showPassword),
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Notice(error!),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : () => submit(),
                child: Text(
                  busy
                      ? 'Connecting…'
                      : register
                      ? 'Create account'
                      : 'Log in',
                ),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      register = !register;
                      error = null;
                    }),
              child: Text(
                register
                    ? 'Already registered? Log in'
                    : 'New partner? Create account',
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => submit(reset: true),
              child: const Text('Forgot password?'),
            ),
            const Notice(
              'Already use Here You Go? Your customer or vendor email and password work here too.',
            ),
          ],
        ),
      ),
    ),
  );
}

class DeliveryHome extends StatefulWidget {
  const DeliveryHome({
    super.key,
    required this.user,
    required this.auth,
    required this.repository,
    required this.onTheme,
    required this.localTesting,
    this.locationService,
  });
  final User user;
  final FirebaseAuth auth;
  final FulfillmentRepository repository;
  final VoidCallback onTheme;
  final bool localTesting;
  final LocationService? locationService;
  @override
  State<DeliveryHome> createState() => _DeliveryHomeState();
}

class _DeliveryHomeState extends State<DeliveryHome> {
  late final state = DeliveryState(
    widget.repository,
    widget.user.uid,
    locationService: widget.locationService,
  );
  int tab = 0;

  void profileSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    if (state.profileError != null) unawaited(state.retryProfileSync());
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  Future<void> logout() async {
    try {
      await state.setOnline(false);
      await widget.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            [
              'Nearby orders',
              'Your delivery',
              'Delivery history',
              'Your profile',
            ][tab],
          ),
          actions: [
            IconButton(
              tooltip: 'Change color theme',
              onPressed: widget.onTheme,
              icon: const Icon(Icons.contrast),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.radar), label: 'Nearby'),
            NavigationDestination(
              icon: Icon(Icons.delivery_dining),
              label: 'Active',
            ),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
        body: SafeArea(
          child: state.loading
              ? const LoadingView(message: 'Connecting delivery profile…')
              : PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.localTesting)
                        const Notice('LOCAL TEST DATABASE'),
                      if (state.error != null) ...[
                        Notice(state.error!, warning: true),
                        const SizedBox(height: 12),
                      ],
                      if (state.profileError != null) ...[
                        Notice(state.profileError!, warning: true),
                        TextButton.icon(
                          onPressed: state.retryProfileSync,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry profile sync'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (state.profile == null) ...[
                        const Notice(
                          'Add your name, phone and vehicle before going online.',
                        ),
                        const SizedBox(height: 16),
                        PartnerProfile(
                          repository: widget.repository,
                          uid: widget.user.uid,
                          onSaved: profileSaved,
                          initial: null,
                          email: widget.user.email ?? '',
                        ),
                      ] else ...[
                        if (tab <= 1) ...[
                          Card(
                            child: SwitchListTile(
                              title: Text(
                                state.goingOnline
                                    ? 'Checking GPS and going online…'
                                    : state.online
                                    ? 'You’re online'
                                    : 'You’re offline',
                              ),
                              subtitle: const Text(
                                'Orders within 5 km of the shop pickup',
                              ),
                              value: state.online,
                              onChanged:
                                  state.busy ||
                                      (!state.online && state.locating)
                                  ? null
                                  : state.setOnline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Keep this app open and online to appear to nearby shops. Leaving the app pauses availability; go online again when you return.',
                          ),
                          const SizedBox(height: 12),
                          DeliveryLocationCard(state: state),
                          if (tab == 0 &&
                              state.location?.position != null &&
                              state.location!.position!.latitude.isFinite &&
                              state.location!.position!.longitude.isFinite) ...[
                            const SizedBox(height: 12),
                            NearbyMap(
                              position: state.location!.position!,
                              offers: state.online ? state.offers : const [],
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        if (tab == 0) ...[
                          if (state.activeOrder != null) ...[
                            const Notice(
                              'You have an active delivery. Complete it before accepting another.',
                            ),
                            FilledButton(
                              onPressed: () => setState(() => tab = 1),
                              child: const Text('Open active delivery'),
                            ),
                          ] else if (!state.online) ...[
                            const EmptyState(
                              icon: Icons.location_on_outlined,
                              title: 'Your next pickup is nearby',
                              message:
                                  'Go online to find available orders within 5 km. Allow precise location when asked.',
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${state.offers.length} nearby orders',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh nearby orders',
                                  onPressed: state.busy ? null : state.refresh,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                            if (state.refreshedAt != null)
                              Text(
                                'Updated ${TimeOfDay.fromDateTime(state.refreshedAt!).format(context)} · refreshes every 20 seconds',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (state.offers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Notice(
                                  'No available pickups within 5 km right now. New preparing and ready orders will appear automatically.',
                                ),
                              ),
                            for (final offer in state.offers)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        StatusBadge(
                                          text: fulfillmentStatus(
                                            offer['status'] as String,
                                          ).toUpperCase(),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          offer['vendorName'] as String,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        Text(
                                          offer['pickup']['address'] as String,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${(offer['distanceKm'] as num).toStringAsFixed(1)} km to pickup · ${(offer['deliveryDistanceKm'] as num).toStringAsFixed(1)} km to customer',
                                        ),
                                        Text(
                                          '${offer['itemCount']} items · Delivery fee ${money(offer['deliveryFeePaise'] as int)}',
                                        ),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: state.busy
                                                ? null
                                                : () async {
                                                    await state.claim(
                                                      offer['reference']
                                                          as String,
                                                    );
                                                    if (mounted &&
                                                        state.error == null) {
                                                      setState(() => tab = 1);
                                                    }
                                                  },
                                            icon: const Icon(Icons.check),
                                            label: Text(
                                              state.busy
                                                  ? 'Assigning…'
                                                  : 'Accept delivery',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                        if (tab == 1) ...[
                          if (state.ordersError != null)
                            Notice(state.ordersError!, warning: true)
                          else if (state.ordersLoading)
                            const LoadingView(
                              message: 'Loading your deliveries…',
                            )
                          else if (state.activeOrder == null)
                            const EmptyState(
                              icon: Icons.delivery_dining,
                              title: 'No active delivery',
                              message:
                                  'Accept a nearby order to see pickup details and customer handover instructions here.',
                            )
                          else
                            FulfillmentOrderCard(
                              order: state.activeOrder!,
                              repository: widget.repository,
                            ),
                        ],
                        if (tab == 2) ...[
                          Text(
                            '${state.completed.length} completed deliveries',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${money(state.earnings)} in completed delivery fees',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This is a delivery fee summary. Payouts and settlement are not processed in this app.',
                          ),
                          const SizedBox(height: 18),
                          if (state.ordersError != null)
                            Notice(state.ordersError!, warning: true),
                          if (state.ordersLoading)
                            const LoadingView(message: 'Loading history…'),
                          if (!state.ordersLoading &&
                              state.orders
                                  .where(
                                    (o) => [
                                      'handedOver',
                                      'cancelled',
                                    ].contains(o['status']),
                                  )
                                  .isEmpty)
                            const Notice(
                              'Completed and cancelled deliveries appear here.',
                            ),
                          for (final order in state.orders.where(
                            (o) => [
                              'handedOver',
                              'cancelled',
                            ].contains(o['status']),
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: FulfillmentOrderCard(
                                order: order,
                                repository: widget.repository,
                              ),
                            ),
                        ],
                        if (tab == 3)
                          PartnerProfile(
                            repository: widget.repository,
                            uid: widget.user.uid,
                            onSaved: profileSaved,
                            initial: state.profile,
                            email: widget.user.email ?? '',
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      );
    },
  );
}

class PartnerProfile extends StatefulWidget {
  const PartnerProfile({
    super.key,
    required this.repository,
    required this.initial,
    required this.email,
    required this.uid,
    this.onSaved,
  });
  final FulfillmentRepository repository;
  final Map<String, dynamic>? initial;
  final String email;
  final String uid;
  final VoidCallback? onSaved;
  @override
  State<PartnerProfile> createState() => _PartnerProfileState();
}

class _PartnerProfileState extends State<PartnerProfile> {
  late final name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final phone = TextEditingController(
    text: widget.initial?['phone'] as String? ?? '',
  );
  late String vehicle = widget.initial?['vehicle'] as String? ?? 'Motorbike';
  bool busy = false;
  String? feedback;
  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      await widget.repository.saveCourierProfile(
        widget.uid,
        name: name.text,
        phone: phone.text,
        vehicle: vehicle,
      );
      widget.onSaved?.call();
      if (mounted) {
        setState(() => feedback = 'Profile saved.');
      }
    } catch (e) {
      if (mounted) setState(() => feedback = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const StatusBadge(text: 'HERE YOU GO · DELIVERY PARTNER'),
      const SizedBox(height: 18),
      Text(widget.email),
      const SizedBox(height: 20),
      TextField(
        controller: name,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Your name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: phone,
        maxLength: 24,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone number'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: vehicle,
        decoration: const InputDecoration(labelText: 'Vehicle'),
        items: [
          for (final value in ['Bicycle', 'Motorbike', 'Car'])
            DropdownMenuItem(value: value, child: Text(value)),
        ],
        onChanged: (v) => setState(() => vehicle = v!),
      ),
      const SizedBox(height: 18),
      if (feedback != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Notice(feedback!),
        ),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save partner profile'),
        ),
      ),
    ],
  );
}

class DeliveryLocationCard extends StatelessWidget {
  const DeliveryLocationCard({super.key, required this.state});
  final DeliveryState state;

  @override
  Widget build(BuildContext context) {
    final fix = state.location, point = fix?.position;
    final synced = state.online && state.locationSyncedAt != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your phone’s location',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              synced
                  ? state.activeOrder == null
                        ? 'GPS synced · nearby shops can find you'
                        : 'GPS synced · tracking your active delivery'
                  : state.online
                  ? 'Waiting for GPS to sync with shops'
                  : 'Offline · your location is not being shared with shops',
            ),
            if (point != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last reading: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
              ),
              if (fix!.accuracyMeters?.isFinite == true)
                Text('GPS accuracy: ±${fix.accuracyMeters!.round()} m'),
              if (fix.capturedAt != null)
                Text(
                  'Captured ${TimeOfDay.fromDateTime(fix.capturedAt!.toLocal()).format(context)}',
                ),
              if (fix.isMocked)
                const Notice(
                  'Your phone reports a simulated location. Disable its mock location app to use real GPS.',
                  warning: true,
                ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Tap below to get your current GPS position. No default city is used.',
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.busy || state.locating
                  ? null
                  : state.refreshLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                state.locating
                    ? 'Getting fresh GPS…'
                    : 'Use my current location',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () =>
                      state.locationService.settings(appSettings: true),
                  child: const Text('Location permission'),
                ),
                TextButton(
                  onPressed: () =>
                      state.locationService.settings(appSettings: false),
                  child: const Text('Device GPS settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NearbyMap extends StatefulWidget {
  const NearbyMap({super.key, required this.position, required this.offers});
  final LatLng position;
  final List<Map<String, dynamic>> offers;
  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  final controller = MapController();
  bool loaded = false, failed = false;
  int generation = 0;
  Timer? timeout;
  LatLng get position => widget.position;
  List<Map<String, dynamic>> get offers => widget.offers;
  @override
  void initState() {
    super.initState();
    watchTiles();
  }

  void watchTiles() {
    timeout?.cancel();
    timeout = Timer(const Duration(seconds: 10), () {
      if (mounted && !loaded) setState(() => failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant NearbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.move(position, controller.camera.zoom);
      });
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: 240,
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: position,
          initialZoom: 12,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: DemoConfig.tileUrl,
            userAgentPackageName: 'com.hereyougo.delivery',
            key: ValueKey(generation),
            tileBuilder: (_, tile, image) {
              if (!loaded && image.imageInfo != null && !image.loadError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !loaded) {
                    timeout?.cancel();
                    setState(() => loaded = true);
                  }
                });
              }
              return tile;
            },
            errorTileCallback: (_, _, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !failed) setState(() => failed = true);
              });
            },
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: position,
                radius: 5000,
                useRadiusInMeter: true,
                color: Colors.blue.withValues(alpha: .08),
                borderColor: Colors.blue,
                borderStrokeWidth: 1,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 48,
                height: 48,
                child: const Tooltip(
                  message: 'Your location',
                  child: Icon(Icons.my_location, color: Colors.blue, size: 30),
                ),
              ),
              for (final o in offers)
                Marker(
                  point: LatLng(
                    (o['pickup']['latitude'] as num).toDouble(),
                    (o['pickup']['longitude'] as num).toDouble(),
                  ),
                  width: 44,
                  height: 44,
                  child: Tooltip(
                    message: o['vendorName'] as String,
                    child: const Icon(
                      Icons.store,
                      color: Colors.deepOrange,
                      size: 30,
                    ),
                  ),
                ),
            ],
          ),
          const MapAttribution(),
          Positioned(
            right: 8,
            bottom: 32,
            child: IconButton.filledTonal(
              tooltip: 'Center map on my GPS location',
              onPressed: () => controller.move(position, 15),
              icon: const Icon(Icons.my_location),
            ),
          ),
          if (!loaded)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: AppTheme.colors(context).surface,
                  borderRadius: BorderRadius.circular(12),
                  child: TextButton.icon(
                    onPressed: failed
                        ? () {
                            setState(() {
                              generation++;
                              failed = false;
                            });
                            watchTiles();
                          }
                        : null,
                    icon: Icon(failed ? Icons.refresh : Icons.map_outlined),
                    label: Text(
                      failed
                          ? 'Map unavailable. Retry; order list still works.'
                          : 'Loading street map…',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
