import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

class OnboardingIndicator extends StatelessWidget {
  const OnboardingIndicator({
    required this.index,
    required this.count,
    super.key,
  });

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (page) {
          return AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: page == index ? 28 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: page == index ? AppColors.emerald : AppColors.outline,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          );
        }),
      ),
    );
  }
}
