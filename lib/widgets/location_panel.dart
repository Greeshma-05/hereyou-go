import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/utils/navigation.dart';
import '../providers/location_provider.dart';
import '../services/location_service.dart';
import 'common.dart';

class LocationPanel extends StatelessWidget {
  const LocationPanel({super.key, this.onLocate, this.showLocateButton = true});
  final Future<void> Function()? onLocate;
  final bool showLocateButton;
  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final state = location.result.state;
    final fix = location.fix;
    final accuracy = fix?.accuracyMeters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Notice(location.result.message, icon: Icons.location_on_outlined),
        if (fix?.position != null) ...[
          const SizedBox(height: 8),
          Text(
            '${fix!.position!.latitude.toStringAsFixed(6)}, ${fix.position!.longitude.toStringAsFixed(6)}',
            key: const ValueKey('device-coordinates'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '${accuracy == null ? 'Accuracy unavailable' : 'Reported accuracy: ±${accuracy.ceil()} m'}'
            '${fix.capturedAt == null ? '' : ' · Captured ${DateFormat('d MMM, h:mm:ss a').format(fix.capturedAt!.toLocal())}'}',
          ),
          if (fix.isMocked) const Text('Test location supplied by the device.'),
          if (fix.approximate || accuracy != null && accuracy > 100)
            const Text(
              'Location is approximate. Enable precise location or try again outdoors.',
            ),
          const Text('Refresh after moving to update nearby shops.'),
        ],
        Wrap(
          spacing: 8,
          children: [
            if (showLocateButton)
              TextButton.icon(
                onPressed: state == LocationState.loading
                    ? null
                    : onLocate ?? location.locate,
                icon: const Icon(Icons.my_location_rounded, size: 17),
                label: Text(
                  state == LocationState.loading
                      ? 'Finding location…'
                      : fix != null
                      ? 'Refresh location'
                      : 'Use my location',
                ),
              ),
            if (state == LocationState.disabled ||
                state == LocationState.deniedForever ||
                fix?.approximate == true)
              TextButton(
                onPressed: () async {
                  final opened = await location.openSettings(
                    preciseLocation: fix?.approximate == true,
                  );
                  if (context.mounted) {
                    showMessage(
                      context,
                      opened
                          ? 'After changing settings, tap Use my location again.'
                          : 'Open location permissions in your device settings.',
                    );
                  }
                },
                child: const Text('Open settings'),
              ),
          ],
        ),
      ],
    );
  }
}
