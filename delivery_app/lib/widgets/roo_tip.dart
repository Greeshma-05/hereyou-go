import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_card.dart';

class RooTip extends StatelessWidget {
  const RooTip({
    required this.message,
    this.title = 'A little help from Roo',
    super.key,
  });
  final String message;
  final String title;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.mintTint,
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RooAvatar(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RooAvatar extends StatelessWidget {
  const RooAvatar({this.size = 46, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Roo, your journey companion',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(size * .35),
      ),
      child: const Icon(Icons.smart_toy_rounded, color: AppColors.background),
    ),
  );
}
