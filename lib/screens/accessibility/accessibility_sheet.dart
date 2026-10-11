import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/accessibility_settings.dart';
import '../../providers/accessibility_provider.dart';
import '../../widgets/common.dart';

class AccessibilitySheet extends StatelessWidget {
  const AccessibilitySheet({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AccessibilityProvider>();
    final colors = AppTheme.colors(context);
    return FractionallySizedBox(
      heightFactor: .94,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reading & appearance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close settings',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose what feels comfortable. Changes apply across the app and are saved on this device.',
                    ),
                    const SizedBox(height: 18),
                    Card(
                      key: const ValueKey('reading-preview'),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your next stop, made easier.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Find food, medicine and travel essentials along your route.',
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                _PreviewStatus(
                                  'In stock',
                                  Icons.check_circle_outline,
                                  colors.accent,
                                ),
                                _PreviewStatus(
                                  'Sold out',
                                  Icons.remove_circle_outline,
                                  colors.warning,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SectionHeading('Reading font'),
                    SwitchListTile(
                      key: const ValueKey('reading-font-toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('OpenDyslexic'),
                      subtitle: const Text(
                        'Distinct letter shapes and more line spacing.',
                      ),
                      value: settings.readingFont,
                      onChanged: settings.setReadingFont,
                    ),
                    const SectionHeading('Text size'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final size in ReadingSize.values)
                          ChoiceChip(
                            key: ValueKey('reading-size-${size.name}'),
                            label: Text('${(size.factor * 100).round()}%'),
                            labelStyle: TextStyle(
                              color: settings.readingSize == size
                                  ? colors.onAccent
                                  : colors.ink,
                            ),
                            selected: settings.readingSize == size,
                            onSelected: (_) => settings.setReadingSize(size),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your device’s text size is always respected.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SectionHeading('Colour theme'),
                    RadioGroup<AppColorTheme>(
                      groupValue: settings.colorTheme,
                      onChanged: (value) {
                        if (value != null) settings.setColorTheme(value);
                      },
                      child: Column(
                        children: [
                          for (final theme in AppColorTheme.values)
                            RadioListTile<AppColorTheme>(
                              key: ValueKey('colour-theme-${theme.name}'),
                              contentPadding: EdgeInsets.zero,
                              value: theme,
                              title: Text(switch (theme) {
                                AppColorTheme.lime => 'Original lime',
                                AppColorTheme.blueAmber => 'Blue & amber',
                                AppColorTheme.highContrast => 'High contrast',
                              }),
                              subtitle: Text(switch (theme) {
                                AppColorTheme.lime =>
                                  'Charcoal with bright lime accents.',
                                AppColorTheme.blueAmber =>
                                  'An alternative to red and green cues.',
                                AppColorTheme.highContrast =>
                                  'White on black, with clear borders.',
                              }),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Notice(
                      'Look for labels and icons as well as colour to check availability and order progress.',
                    ),
                    if (settings.error != null) ...[
                      const SizedBox(height: 12),
                      Notice(settings.error!, warning: true),
                    ],
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: settings.reset,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restore defaults'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStatus extends StatelessWidget {
  const _PreviewStatus(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: TextStyle(color: color)),
      ),
    ],
  );
}
