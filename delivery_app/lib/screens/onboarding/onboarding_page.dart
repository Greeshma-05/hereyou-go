import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/journey_illustration.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required this.number,
    required this.caption,
    required this.title,
    required this.description,
    required this.scene,
    super.key,
  });

  final int number;
  final String caption;
  final String title;
  final String description;
  final JourneyScene scene;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: PageStorageKey('onboarding-$number'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compactPageInset,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JourneyIllustration(scene: scene),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '0$number / $caption',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.emerald,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(title, style: textTheme.headlineLarge),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
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
