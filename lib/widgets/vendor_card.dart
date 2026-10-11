import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/navigation.dart';
import '../models/nearby_area.dart';
import '../models/vendor_model.dart';
import '../providers/journey_provider.dart';
import '../providers/location_provider.dart';
import '../screens/vendor/vendor_screen.dart';
import 'category_chip.dart';
import 'common.dart';

class VendorCard extends StatelessWidget {
  const VendorCard({
    super.key,
    required this.vendor,
    this.onTap,
    this.matchLabel,
    this.highlight = false,
  });
  final Vendor vendor;
  final VoidCallback? onTap;
  final String? matchLabel;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyProvider>();
    final area = NearbyArea(
      mode: journey.searchMode,
      devicePosition: context.watch<LocationProvider>().position,
      pickup: journey.journey?.pickup,
    );
    final distance = area.distanceKm(vendor.position);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: highlight
              ? AppTheme.colors(context).accent.withValues(alpha: .6)
              : AppTheme.colors(context).border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            onTap ?? () => openPage(context, VendorScreen(vendorId: vendor.id)),
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryArtwork(vendor.category, size: 66),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${vendor.category.label} · ${vendor.area}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 7),
                    Text(
                      '${distance.toStringAsFixed(1)} km from ${area.source} · ${vendor.preparationMinutes} min prep',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(text: vendor.available ? 'OPEN' : 'CLOSED'),
                        Text(
                          vendor.isSample ? '★ ${vendor.rating}' : 'New shop',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.colors(context).muted,
                          ),
                        ),
                      ],
                    ),
                    if (matchLabel != null) ...[
                      SizedBox(height: 10),
                      Text(
                        matchLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: highlight
                              ? AppTheme.colors(context).accent
                              : AppTheme.colors(context).muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
