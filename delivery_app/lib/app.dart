import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'screens/app_entry.dart';
import 'services/account_gateway.dart';
import 'services/onboarding_store.dart';

class RouteRescuePartnerApp extends StatelessWidget {
  const RouteRescuePartnerApp({
    this.onboardingStore,
    this.accountGateway = const UnavailableAccountGateway(),
    super.key,
  });

  final OnboardingStore? onboardingStore;
  final AccountGateway accountGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: AppEntry(
        onboardingStore: onboardingStore,
        accountGateway: accountGateway,
      ),
    );
  }
}
