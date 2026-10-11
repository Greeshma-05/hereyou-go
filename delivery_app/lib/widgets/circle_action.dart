import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class CircleAction extends StatelessWidget {
  const CircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.count = 0,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int count;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    backgroundColor: AppColors.lime,
    textColor: AppColors.background,
    child: IconButton.filledTonal(
      tooltip: count > 0 ? '$label, $count unread' : label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: AppColors.surface,
      ),
      icon: Icon(icon, color: AppColors.textPrimary),
    ),
  );
}
