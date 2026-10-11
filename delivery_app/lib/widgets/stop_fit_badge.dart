import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/stop_fit_result.dart';

class StopFitBadge extends StatelessWidget {
  const StopFitBadge({required this.result, super.key});
  final StopFitResult result;
  @override
  Widget build(BuildContext context) {
    final warning =
        result.classification.index >= StopFitClassification.tight.index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningTint : AppColors.mintTint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        'StopFit · ${result.label}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: warning ? AppColors.warningText : AppColors.lime,
          letterSpacing: .4,
        ),
      ),
    );
  }
}
