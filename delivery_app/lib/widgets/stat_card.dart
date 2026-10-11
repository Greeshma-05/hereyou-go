import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_card.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    required this.value,
    required this.label,
    required this.icon,
    super.key,
  });
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 16),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: AppColors.lime),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
