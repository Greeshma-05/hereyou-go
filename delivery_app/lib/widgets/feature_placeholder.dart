import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'app_card.dart';
import 'app_page.dart';
import 'empty_state.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.storageId,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emptyTitle,
    required this.description,
    this.action,
    super.key,
  });

  final String storageId;
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final String emptyTitle;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      storageId: storageId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: textTheme.labelSmall?.copyWith(color: AppColors.emerald),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(title, style: textTheme.headlineLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: EmptyState(
              icon: icon,
              title: emptyTitle,
              description: description,
              action: action,
            ),
          ),
        ],
      ),
    );
  }
}
