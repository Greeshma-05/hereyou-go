import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class RouteInfoRow extends StatelessWidget {
  const RouteInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.lime, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 5),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
