import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'package:route_rescue/providers/location_provider.dart';
import 'package:route_rescue/widgets/common.dart';
import 'screens/auth_screen.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'screens/dashboard_screen.dart';
import 'state/merchant_state.dart';

class VendorApp extends StatelessWidget {
  const VendorApp({
    super.key,
    required this.repository,
    this.setupError,
    this.fulfillment,
    this.localTesting = false,
  });
  final MerchantRepository? repository;
  final String? setupError;
  final FulfillmentRepository? fulfillment;
  final bool localTesting;
  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: repository?.authChanges,
    builder: (context, snapshot) {
      final uid = snapshot.data;
      return MultiProvider(
        key: ValueKey(uid ?? 'signed-out'),
        providers: [
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          if (uid != null && repository != null)
            ChangeNotifierProvider(
              create: (_) => MerchantState(repository!, uid),
            ),
        ],
        child: MaterialApp(
          title: 'Here You Go Vendor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          builder: (context, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (localTesting)
                Material(
                  color: AppTheme.colors(context).tint,
                  child: const SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'LOCAL TEST DATABASE',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: localTesting,
                  child: child!,
                ),
              ),
            ],
          ),
          home: repository == null
              ? Scaffold(
                  appBar: AppBar(title: const Text('Vendor setup')),
                  body: PageBody(
                    child: Notice(
                      setupError ?? 'Firebase configuration is needed.',
                    ),
                  ),
                )
              : snapshot.hasError
              ? Scaffold(
                  body: PageBody(child: Notice(merchantError(snapshot.error!))),
                )
              : snapshot.connectionState == ConnectionState.waiting
              ? const Scaffold(
                  body: LoadingView(message: 'Restoring vendor account…'),
                )
              : uid == null
              ? VendorAuthScreen(repository: repository!)
              : DashboardScreen(fulfillment: fulfillment),
        ),
      );
    },
  );
}
