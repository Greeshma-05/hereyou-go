import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/demo_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../data/courier_tracking_source.dart';
import '../../models/delivery_route.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/map_attribution.dart';

class DeliveryRouteMap extends StatefulWidget {
  const DeliveryRouteMap({
    super.key,
    required this.shop,
    required this.destination,
    required this.shopName,
    required this.destinationName,
    this.route,
    this.courier,
    this.courierLive = false,
    this.bottomInset = 0,
  });
  final LatLng? shop;
  final LatLng destination;
  final String shopName;
  final String destinationName;
  final DeliveryRoute? route;
  final CourierFix? courier;
  final bool courierLive;
  final double bottomInset;
  @override
  State<DeliveryRouteMap> createState() => _DeliveryRouteMapState();
}

class _DeliveryRouteMapState extends State<DeliveryRouteMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _tileError = false;
  bool _hasTiles = false;
  int _tileGeneration = 0;
  Timer? _tileTimeout;

  @override
  void initState() {
    super.initState();
    _watchTiles();
  }

  void _watchTiles() {
    _tileTimeout?.cancel();
    _tileTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && !_hasTiles) setState(() => _tileError = true);
    });
  }

  CameraFit get _fit => CameraFit.coordinates(
    coordinates: [
      if (widget.shop != null) widget.shop!,
      widget.destination,
      ...?widget.route?.points,
      if (widget.courier != null) widget.courier!.position,
    ],
    padding: EdgeInsets.fromLTRB(55, 95, 70, widget.bottomInset + 55),
    maxZoom: 16,
  );

  @override
  void didUpdateWidget(covariant DeliveryRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready) _controller.fitCamera(_fit);
      });
    }
  }

  @override
  void dispose() {
    _tileTimeout?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final location = context.read<LocationProvider>();
    await location.locate();
    if (!mounted) return;
    if (location.result.state == LocationState.ready && _ready) {
      _controller.move(
        location.position!,
        16,
        offset: Offset(0, -widget.bottomInset / 2),
      );
      showMessage(
        context,
        'Your device location · ±${location.fix!.accuracyMeters?.round() ?? '—'} m. The delivery pin stays at your saved address.',
      );
    } else {
      showMessage(context, location.result.message);
    }
  }

  Marker _pin({
    required String id,
    required LatLng point,
    required String label,
    required IconData icon,
    required Color color,
    required Color foreground,
    bool square = false,
  }) => Marker(
    key: ValueKey(id),
    point: point,
    width: 50,
    height: 50,
    child: Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(square ? 12 : 25),
            border: Border.all(
              color: AppTheme.colors(context).canvas,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: foreground, size: 27),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final location = context.watch<LocationProvider>();
    final route = widget.route;
    final courier = widget.courier;
    return Stack(
      children: [
        FlutterMap(
          key: const ValueKey('order-delivery-map'),
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: _fit,
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
              tileBuilder: (_, tile, image) {
                if (!_hasTiles && image.imageInfo != null && !image.loadError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_hasTiles) {
                      _tileTimeout?.cancel();
                      setState(() => _hasTiles = true);
                    }
                  });
                }
                return tile;
              },
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
            if (route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.points,
                    color: colors.accent,
                    strokeWidth: 6,
                    borderColor: colors.canvas,
                    borderStrokeWidth: 2,
                  ),
                  // Dotted connections show the gap between a pin and the nearest road.
                  if (widget.shop != null &&
                      const Distance()(widget.shop!, route.points.first) > 5)
                    Polyline(
                      points: [widget.shop!, route.points.first],
                      color: colors.canvas,
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                  if (const Distance()(widget.destination, route.points.last) >
                      5)
                    Polyline(
                      points: [route.points.last, widget.destination],
                      color: colors.canvas,
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                ],
              ),
            CircleLayer(
              circles: [
                if (location.position != null &&
                    location.fix?.accuracyMeters != null)
                  CircleMarker(
                    point: location.position!,
                    radius: location.fix!.accuracyMeters!,
                    useRadiusInMeter: true,
                    color: colors.ink.withValues(alpha: .15),
                    borderColor: colors.canvas,
                    borderStrokeWidth: 1,
                  ),
                if (courier?.accuracyMeters != null)
                  CircleMarker(
                    point: courier!.position,
                    radius: courier.accuracyMeters!,
                    useRadiusInMeter: true,
                    color: colors.warning.withValues(alpha: .15),
                    borderColor: colors.warning,
                    borderStrokeWidth: 1,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (widget.shop != null)
                  _pin(
                    id: 'delivery-shop-pin',
                    point: widget.shop!,
                    label: 'Shop: ${widget.shopName}',
                    icon: Icons.storefront_outlined,
                    color: colors.canvas,
                    foreground: colors.ink,
                  ),
                _pin(
                  id: 'delivery-destination-pin',
                  point: widget.destination,
                  label: 'Delivery: ${widget.destinationName}',
                  icon: Icons.flag_outlined,
                  color: colors.accent,
                  foreground: colors.onAccent,
                  square: true,
                ),
                if (location.position != null)
                  _pin(
                    id: 'delivery-device-pin',
                    point: location.position!,
                    label: 'Your device location',
                    icon: Icons.my_location,
                    color: colors.ink,
                    foreground: colors.canvas,
                  ),
                if (courier != null)
                  _pin(
                    id: 'delivery-courier-pin',
                    point: courier.position,
                    label: widget.courierLive
                        ? 'Courier location'
                        : 'Last reported courier location',
                    icon: Icons.delivery_dining,
                    color: colors.warning,
                    foreground: colors.canvas,
                  ),
              ],
            ),
            const MapAttribution(alignment: Alignment.topCenter),
          ],
        ),
        Positioned(
          top: 62,
          right: 10,
          child: Column(
            children: [
              IconButton.filledTonal(
                tooltip: 'Fit delivery route',
                onPressed: () {
                  if (_ready) _controller.fitCamera(_fit);
                },
                icon: const Icon(Icons.fit_screen),
              ),
              const SizedBox(height: 6),
              IconButton.filledTonal(
                tooltip: 'Show my location',
                onPressed: location.result.state == LocationState.loading
                    ? null
                    : _locate,
                icon: const Icon(Icons.my_location),
              ),
              if (_tileError) ...[
                const SizedBox(height: 6),
                IconButton.filledTonal(
                  tooltip: 'Map unavailable. Retry map tiles',
                  onPressed: () => setState(() {
                    _tileError = false;
                    _hasTiles = false;
                    _tileGeneration++;
                    _watchTiles();
                  }),
                  icon: const Icon(Icons.cloud_off_outlined),
                ),
              ],
            ],
          ),
        ),
        if (!_hasTiles)
          Positioned(
            top: 64,
            left: 12,
            right: 72,
            child: IgnorePointer(
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _tileError
                        ? 'Street map unavailable. Your pins are still shown.'
                        : 'Loading street map…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
