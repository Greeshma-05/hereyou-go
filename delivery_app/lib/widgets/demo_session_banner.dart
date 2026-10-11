import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/partner_session.dart';

class DemoSessionBanner extends StatelessWidget {
  const DemoSessionBanner({required this.session, super.key});

  final PartnerSession session;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: session.isAuthenticated
          ? '${session.name}. Signed in. Deliveries, availability and earnings are simulated.'
          : '${session.name}. Demo account. ${session.isOnline ? 'Online' : 'Offline'}. No backend authentication.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        color: AppColors.mintTint,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compactPageInset,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 20, color: AppColors.lime),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${session.isAuthenticated ? 'Sample deliveries' : 'Demo mode'} · ${session.isOnline ? 'Online' : 'Offline'}',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: AppColors.lime),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
