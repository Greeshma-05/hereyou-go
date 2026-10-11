import 'package:flutter/material.dart';
import '../providers/catalog_provider.dart';
import '../models/nearby_area.dart';
import 'common.dart';

class CatalogStatus extends StatelessWidget {
  const CatalogStatus({super.key, this.area});
  final NearbyArea? area;
  @override
  Widget build(BuildContext context) {
    final catalog = CatalogProvider.of(context);
    if (!catalog.live) return const SizedBox.shrink();
    final matching = area == null
        ? catalog.vendors.length
        : catalog.vendors.where((v) => area!.contains(v.position)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catalog.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Updating nearby shops…'),
          ),
        if (catalog.error != null) ...[
          Notice(catalog.error!, warning: true),
          TextButton(
            onPressed: catalog.retry,
            child: const Text('Retry shop catalog'),
          ),
        ],
        if (catalog.truncated)
          const Notice(
            'This area has many shops. Results are limited; move the location pin closer to the shops you need.',
          ),
        if (!catalog.loading &&
            catalog.error == null &&
            catalog.vendors.isEmpty)
          const Notice(
            'No published shops nearby yet. Shops will appear here after vendors publish their location and products.',
          ),
        if (!catalog.loading &&
            catalog.error == null &&
            catalog.vendors.isNotEmpty)
          Notice(
            matching == 0 && area != null
                ? 'Published shops were found, but none is ${area!.distanceLabel} from your ${area!.source}. Change travel mode or search location.'
                : '$matching ${matching == 1 ? 'shop' : 'shops'} ${area?.distanceLabel ?? 'nearby'} · Product and stock changes update automatically.',
            icon: Icons.sync,
          ),
      ],
    );
  }
}
