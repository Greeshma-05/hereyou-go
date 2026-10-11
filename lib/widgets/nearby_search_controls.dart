import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/navigation.dart';
import '../models/journey_model.dart';
import '../models/nearby_area.dart';
import '../providers/journey_provider.dart';
import '../providers/location_provider.dart';
import '../screens/journey/journey_screen.dart';
import '../services/location_service.dart';

/// Home and Explore use the same location and travel mode for live inventory.
class NearbySearchControls extends StatelessWidget {
  const NearbySearchControls({super.key, this.onLocate});
  final Future<void> Function()? onLocate;

  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyProvider>();
    final location = context.watch<LocationProvider>();
    final area = NearbyArea(
      mode: journey.searchMode,
      devicePosition: location.position,
      pickup: journey.journey?.pickup,
    );
    final colors = AppTheme.colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final mode in JourneyMode.values)
              ChoiceChip(
                label: Text(NearbyArea(mode: mode).rangeLabel),
                labelStyle: TextStyle(
                  color: journey.searchMode == mode
                      ? colors.onAccent
                      : colors.ink,
                ),
                selected: journey.searchMode == mode,
                onSelected: (_) => journey.setSearchMode(mode),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          area.isPreview
              ? 'Choose your location to find shops near you.'
              : 'Searching from your ${area.source}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          area.isPreview
              ? 'Currently browsing the Kochi preview area.'
              : '${area.center.latitude.toStringAsFixed(5)}, ${area.center.longitude.toStringAsFixed(5)}'
                    '${area.source == 'delivery pin' ? ' · ${journey.journey!.pickup.name}' : ''}',
          key: const ValueKey('shop-search-center'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: location.result.state == LocationState.loading
                  ? null
                  : onLocate ??
                        () async {
                          await location.locate();
                          if (context.mounted &&
                              location.result.state != LocationState.ready) {
                            showMessage(context, location.result.message);
                          }
                        },
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                location.result.state == LocationState.loading
                    ? 'Finding location…'
                    : location.position == null
                    ? 'Use my location'
                    : 'Refresh location',
              ),
            ),
            if (location.position != null && journey.journey != null)
              TextButton.icon(
                onPressed: location.clear,
                icon: const Icon(Icons.place_outlined, size: 18),
                label: const Text('Use delivery pin'),
              ),
            TextButton.icon(
              onPressed: () =>
                  openPage(context, const JourneyScreen(focusDelivery: true)),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Change delivery location'),
            ),
          ],
        ),
      ],
    );
  }
}
