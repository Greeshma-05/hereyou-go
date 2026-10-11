import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/navigation.dart';

/// Wraps at larger text sizes instead of overflowing the map viewport.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.alignment = Alignment.bottomCenter});
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Material(
      color: AppTheme.colors(context).surface,
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontSize: 12),
          ),
          onPressed: () async {
            try {
              final opened = await launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                showMessage(
                  context,
                  'Map data © OpenStreetMap contributors · openstreetmap.org/copyright',
                );
              }
            } catch (_) {
              if (context.mounted) {
                showMessage(
                  context,
                  'Map data © OpenStreetMap contributors · openstreetmap.org/copyright',
                );
              }
            }
          },
          child: const Text(
            '© OpenStreetMap contributors',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
