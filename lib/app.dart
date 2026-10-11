import 'core/constants/app_brand.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/user_repository.dart';
import 'data/catalog_repository.dart';
import 'providers/catalog_provider.dart';
import 'models/nearby_area.dart';
import 'providers/cart_provider.dart';
import 'providers/accessibility_provider.dart';
import 'providers/journey_provider.dart';
import 'providers/location_provider.dart';
import 'providers/order_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/session_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'widgets/common.dart';

class RouteRescueApp extends StatelessWidget {
  const RouteRescueApp({
    super.key,
    this.preferences,
    this.repository,
    this.setupError,
    this.catalogRepository,
    this.restoreLocation = false,
  });
  final SharedPreferences? preferences;
  final UserRepository? repository;
  final String? setupError;
  final CatalogRepository? catalogRepository;
  final bool restoreLocation;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AccessibilityProvider(preferences),
    child: _SessionApp(
      preferences: preferences,
      repository: repository,
      setupError: setupError,
      catalogRepository: catalogRepository,
      restoreLocation: restoreLocation,
    ),
  );
}

class _SessionApp extends StatelessWidget {
  const _SessionApp({
    this.preferences,
    this.repository,
    this.setupError,
    this.catalogRepository,
    this.restoreLocation = false,
  });
  final SharedPreferences? preferences;
  final UserRepository? repository;
  final String? setupError;
  final CatalogRepository? catalogRepository;
  final bool restoreLocation;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        SessionProvider(repository: repository, setupError: setupError),
    child: Consumer<SessionProvider>(
      builder: (context, session, _) {
        final customer = session.customer;
        // Recreate all account-scoped state and navigation on account changes.
        // A late snapshot from the old account can never populate the new account.
        return MultiProvider(
          key: ValueKey(
            customer?.uid ?? (customer == null ? 'signed-out' : 'guest'),
          ),
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  JourneyProvider(repository: repository, uid: customer?.uid),
            ),
            ChangeNotifierProvider(
              create: (_) {
                final location = LocationProvider();
                if (restoreLocation) location.restoreIfPermitted();
                return location;
              },
            ),
            ChangeNotifierProxyProvider2<
              JourneyProvider,
              LocationProvider,
              CatalogProvider
            >(
              create: (_) => CatalogProvider(repository: catalogRepository),
              update: (_, journey, location, catalog) {
                catalog!.setCenter(
                  NearbyArea(
                    mode: journey.searchMode,
                    devicePosition: location.position,
                    pickup: journey.journey?.pickup,
                  ).center,
                );
                return catalog;
              },
            ),
            ChangeNotifierProvider(
              create: (context) =>
                  CartProvider(catalog: context.read<CatalogProvider>()),
            ),
            ChangeNotifierProvider(
              create: (context) => OrderProvider(
                repository: repository,
                uid: customer?.uid,
                catalog: context.read<CatalogProvider>(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => PreferencesProvider(
                preferences,
                repository: repository,
                uid: customer?.uid,
              ),
            ),
          ],
          child: Consumer<AccessibilityProvider>(
            builder: (context, appearance, _) => MaterialApp(
              title: AppBrand.name,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(
                colorTheme: appearance.colorTheme,
                readingFont: appearance.readingFont,
              ),
              themeAnimationDuration: Duration.zero,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                final scaler = ReadingTextScaler(
                  media.textScaler,
                  appearance.readingSize.factor,
                );
                final theme = Theme.of(context);
                return MediaQuery(
                  data: media.copyWith(textScaler: scaler),
                  child: Theme(
                    data: theme.copyWith(
                      appBarTheme: theme.appBarTheme.copyWith(
                        toolbarHeight: math.max(
                          64,
                          scaler.scale(21) *
                                  (appearance.readingFont ? 1.5 : 1.2) +
                              20,
                        ),
                      ),
                    ),
                    child: child!,
                  ),
                );
              },
              home: const _SessionGate(),
            ),
          ),
        );
      },
    ),
  );
}

/// Preserve platform (including nonlinear) scaling, then apply the user's choice.
class ReadingTextScaler extends TextScaler {
  const ReadingTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) =>
      other is ReadingTextScaler &&
      other.system == system &&
      other.factor == factor;
  @override
  int get hashCode => Object.hash(system, factor);
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (session.initializing || session.busy && session.customer != null) {
      return const Scaffold(
        body: LoadingView(message: 'Connecting your account…'),
      );
    }
    if (session.customer != null) return const MainShell();
    if (!session.introduced) return const OnboardingScreen();
    return const AuthScreen();
  }
}
