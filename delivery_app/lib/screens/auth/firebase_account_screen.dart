import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/firebase_account.dart';
import '../../services/account_gateway.dart';
import '../../widgets/app_brand.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/cinematic_background.dart';

/// Optional account details opened from Profile; never gates the delivery tools.
class FirebaseAccountScreen extends StatefulWidget {
  const FirebaseAccountScreen({
    required this.account,
    required this.gateway,
    super.key,
  });

  final FirebaseAccount account;
  final AccountGateway gateway;

  @override
  State<FirebaseAccountScreen> createState() => _FirebaseAccountScreenState();
}

class _FirebaseAccountScreenState extends State<FirebaseAccountScreen> {
  late Future<AccountProfile?> _profile = widget.gateway.loadProfile();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Account details')),
      body: CinematicBackground(
        child: SafeArea(
          child: AppPage(
            storageId: 'firebase-account',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppBrand(),
                const SizedBox(height: 32),
                Text('Account connected', style: text.headlineLarge),
                const SizedBox(height: 12),
                Text(widget.account.email, style: text.bodyLarge),
                if (widget.account.setupMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(widget.account.setupMessage!),
                  ),
                ],
                const SizedBox(height: 24),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.lime,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text('Your RouteRescue account', style: text.titleLarge),
                      const SizedBox(height: 12),
                      const Text(
                        'You are signed in. All delivery tools are available from Mission Control. Requests, routes and earnings currently use sample data; live customer assignments are not connected yet.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  child: FutureBuilder<AccountProfile?>(
                    future: _profile,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Row(
                          children: [
                            SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 16),
                            Expanded(child: Text('Loading saved profile…')),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your saved profile', style: text.titleMedium),
                          const SizedBox(height: 12),
                          if (snapshot.hasError)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                snapshot.error is AccountFailure
                                    ? (snapshot.error! as AccountFailure)
                                          .message
                                    : 'Could not load your profile. Please retry.',
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            )
                          else if (snapshot.data == null)
                            const Text(
                              'No saved profile was found for this account. No customer records were changed.',
                            )
                          else ...[
                            Text(
                              snapshot.data!.displayName,
                              style: text.titleMedium,
                            ),
                            Text(snapshot.data!.email),
                          ],
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _profile = widget.gateway.loadProfile();
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reload profile'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
