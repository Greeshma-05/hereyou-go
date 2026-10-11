import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../core/constants/demo_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../models/nearby_area.dart';
import '../../models/vendor_model.dart';
import '../../providers/journey_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/common.dart';
import '../../widgets/map_attribution.dart';
import '../../widgets/vendor_card.dart';
import '../vendor/vendor_screen.dart';

class VendorMap extends StatefulWidget {
  const VendorMap({
    super.key,
    required this.vendors,
    required this.area,
    this.locationRevision,
  });
  final List<Vendor> vendors;
  final NearbyArea area;
  final DateTime? locationRevision;
  @override
  State<VendorMap> createState() => _VendorMapState();
}

class _VendorMapState extends State<VendorMap> {
  final _controller = MapController();
  bool _tileError = false;
  int _tileGeneration = 0;
  bool _ready = false;
  double get _zoom => widget.area.radiusKm == 7 ? 12 : 10.5;

  @override
  void didUpdateWidget(covariant VendorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area.center != widget.area.center ||
        oldWidget.area.mode != widget.area.mode ||
        oldWidget.locationRevision != widget.locationRevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready) _controller.move(widget.area.center, _zoom);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final location = context.read<LocationProvider>();
    await location.locate();
    if (!mounted) return;
    if (location.result.state == LocationState.ready &&
        location.position != null &&
        _ready) {
      _controller.move(location.position!, 15);
    } else {
      showMessage(context, location.result.message);
    }
  }

  void _showVendor(Vendor vendor) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StatusBadge(text: 'NEARBY SHOP'),
              const SizedBox(height: 14),
              VendorCard(
                vendor: vendor,
                onTap: () {
                  Navigator.pop(sheetContext);
                  openPage(context, VendorScreen(vendorId: vendor.id));
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    openPage(context, VendorScreen(vendorId: vendor.id));
                  },
                  child: const Text('Browse essentials'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final fix = location.fix;
    final position = location.position;
    final pickup = context.watch<JourneyProvider>().journey?.pickup;
    final colors = AppTheme.colors(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 340,
            child: Stack(
              children: [
                FlutterMap(
                  key: const ValueKey('explore-map'),
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.area.center,
                    initialZoom: _zoom,
                    minZoom: 2,
                    maxZoom: 19,
                    onMapReady: () => _ready = true,
                    backgroundColor: colors.surface,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey(_tileGeneration),
                      urlTemplate: DemoConfig.tileUrl,
                      userAgentPackageName: 'com.app',
                      maxNativeZoom: 19,
                      errorTileCallback: (_, _, _) {
                        if (!_tileError) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_tileError) {
                              setState(() => _tileError = true);
                            }
                          });
                        }
                      },
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: widget.area.center,
                          radius: widget.area.radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: colors.accent.withValues(alpha: .04),
                          borderColor: colors.accent,
                          borderStrokeWidth: 2,
                        ),
                        if (widget.area.minimumKm > 0)
                          CircleMarker(
                            point: widget.area.center,
                            radius: widget.area.minimumKm * 1000,
                            useRadiusInMeter: true,
                            color: colors.canvas.withValues(alpha: .15),
                            borderColor: colors.muted,
                            borderStrokeWidth: 2,
                          ),
                        if (position != null && fix?.accuracyMeters != null)
                          CircleMarker(
                            point: position,
                            radius: fix!.accuracyMeters!,
                            useRadiusInMeter: true,
                            color: colors.warning.withValues(alpha: .2),
                            borderColor: colors.warning,
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final vendor in widget.vendors)
                          Marker(
                            key: ValueKey('map-vendor-${vendor.id}'),
                            point: vendor.position,
                            width: 52,
                            height: 52,
                            child: Semantics(
                              label:
                                  '${vendor.name}, ${vendor.available ? 'open' : 'closed'}',
                              button: true,
                              child: IconButton.filled(
                                tooltip: vendor.name,
                                style: IconButton.styleFrom(
                                  backgroundColor: vendor.available
                                      ? colors.accent
                                      : colors.surface,
                                  side: BorderSide(
                                    color: vendor.available
                                        ? colors.canvas
                                        : colors.ink,
                                    width: 3,
                                  ),
                                ),
                                onPressed: () => _showVendor(vendor),
                                icon: Icon(
                                  vendor.available
                                      ? categoryIcon(vendor.category)
                                      : Icons.block,
                                  color: vendor.available
                                      ? colors.onAccent
                                      : colors.ink,
                                  size: 23,
                                ),
                              ),
                            ),
                          ),
                        if (pickup != null)
                          Marker(
                            point: pickup.position,
                            width: 42,
                            height: 42,
                            child: Tooltip(
                              message: 'Delivery pin: ${pickup.name}',
                              child: Icon(
                                Icons.flag_circle_rounded,
                                color: colors.warning,
                                size: 38,
                              ),
                            ),
                          ),
                        if (position != null)
                          Marker(
                            point: position,
                            width: 44,
                            height: 44,
                            child: Semantics(
                              key: const ValueKey('device-location-marker'),
                              label: 'Your device location',
                              child: Tooltip(
                                message: 'Your device location',
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.ink,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.canvas,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.my_location,
                                    color: colors.canvas,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const MapAttribution(),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Show shop range',
                        onPressed: () =>
                            _controller.move(widget.area.center, _zoom),
                        icon: const Icon(Icons.storefront_outlined),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Center on my location',
                        onPressed:
                            location.result.state == LocationState.loading
                            ? null
                            : _locate,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_tileError) ...[
          const SizedBox(height: 10),
          const Notice(
            'Some map tiles could not load. Your coordinates and filtered shop list are still available.',
            warning: true,
          ),
          TextButton(
            onPressed: () => setState(() {
              _tileError = false;
              _tileGeneration++;
            }),
            child: const Text('Retry map tiles'),
          ),
        ],
      ],
    );
  }
}
