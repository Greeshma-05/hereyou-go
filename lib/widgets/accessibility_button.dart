import 'package:flutter/material.dart';
import '../screens/accessibility/accessibility_sheet.dart';

class AccessibilityButton extends StatelessWidget {
  const AccessibilityButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Reading & appearance',
    icon: const Icon(Icons.accessibility_new_rounded),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => const AccessibilitySheet(),
    ),
  );
}
