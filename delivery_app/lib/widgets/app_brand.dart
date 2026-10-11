import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({this.onDark = false, super.key});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.appName,
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: onDark ? AppColors.mint : AppColors.forest,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(
              Icons.route_rounded,
              color: onDark ? AppColors.forest : AppColors.mint,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RouteRescue',
                    style: AppTextStyles.wordmark.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'PARTNER',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: onDark ? AppColors.mint : AppColors.emerald,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
