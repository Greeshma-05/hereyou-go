import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../data/demo_data.dart';
import '../models/delivery_request.dart';
import '../models/route_stop.dart';
import 'glass_panel.dart';
import 'route_canvas.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({
    required this.orders,
    required this.onSelected,
    this.selectedId,
    this.stops = DemoData.stops,
    this.tileProvider,
    super.key,
  });
  final List<DeliveryRequest> orders;
  final ValueChanged<DeliveryRequest> onSelected;
  final String? selectedId;
  final List<RouteStop> stops;
  final TileProvider? tileProvider;
  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _transform = TransformationController();
  bool _streetTiles = false;
  bool _loaded = false;
  bool _failed = false;
  bool _failureScheduled = false;
  Timer? _timeout;

  @override
  void dispose() {
    _timeout?.cancel();
    _transform.dispose();
    super.dispose();
  }

  void _toggle(bool enabled) {
    _timeout?.cancel();
    setState(() {
      _streetTiles = enabled;
      _loaded = false;
      _failed = false;
      _failureScheduled = false;
    });
    if (enabled) {
      _timeout = Timer(const Duration(seconds: 8), () {
        if (!_loaded) _tileFailure();
      });
    }
  }

  void _tileFailure() {
    if (!mounted || _failureScheduled || !_streetTiles) return;
    _failureScheduled = true;
    _timeout?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _streetTiles = false;
        });
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _tileLoaded() {
    if (_loaded) return;
    _loaded = true;
    _timeout?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  LatLng _point(RouteStop stop) => LatLng(stop.latitude!, stop.longitude!);
  Widget _opportunity(DeliveryRequest order) => IconButton.filled(
    tooltip: 'Select ${order.id}',
    onPressed: () => widget.onSelected(order),
    style: IconButton.styleFrom(
      backgroundColor: widget.selectedId == order.id
          ? AppColors.lime
          : AppColors.surface,
      foregroundColor: widget.selectedId == order.id
          ? AppColors.background
          : AppColors.lime,
      side: const BorderSide(color: AppColors.lime),
    ),
    icon: const Icon(Icons.inventory_2_outlined, size: 20),
  );

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops.where((s) => s.hasCoordinates).toList();
    final coordinatesAvailable = stops.length >= 2;
    final height = (MediaQuery.sizeOf(context).height * .58).clamp(
      320.0,
      500.0,
    );
    final selected = widget.orders
        .where((o) => o.id == widget.selectedId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Street tiles unavailable. The offline diagram and mission details still work.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.warningText),
              ),
            ),
          ),
        if (!coordinatesAvailable ||
            widget.orders.any(
              (o) => !o.pickup.hasCoordinates || !o.handover.hasCoordinates,
            ))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Some route coordinates are missing. Use the stop names and offline diagram.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.warningText),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _streetTiles && coordinatesAvailable
                      ? FlutterMap(
                          options: MapOptions(
                            initialCameraFit: CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(
                                stops.map(_point).toList(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                50,
                                110,
                                50,
                                70,
                              ),
                            ),
                            backgroundColor: AppColors.secondaryBackground,
                            minZoom: 7,
                            maxZoom: 17,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.app',
                              tileProvider: widget.tileProvider,
                              panBuffer: 0,
                              maxNativeZoom: 19,
                              tileBuilder: (context, tileWidget, tile) {
                                if (tile.loadFinishedAt != null &&
                                    !tile.loadError) {
                                  _tileLoaded();
                                }
                                return darkModeTilesContainerBuilder(
                                  context,
                                  tileWidget,
                                );
                              },
                              errorTileCallback: (_, error, stackTrace) =>
                                  _tileFailure(),
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: stops.map(_point).toList(),
                                  color: AppColors.lime.withValues(alpha: .25),
                                  strokeWidth: 12,
                                ),
                                Polyline(
                                  points: stops.map(_point).toList(),
                                  color: AppColors.lime,
                                  strokeWidth: 3,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                for (final stop in stops)
                                  Marker(
                                    point: _point(stop),
                                    width: 20,
                                    height: 20,
                                    child: Tooltip(
                                      message: stop.name,
                                      child: const Icon(
                                        Icons.trip_origin,
                                        color: AppColors.lime,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                for (final order in widget.orders.where(
                                  (o) => o.pickup.hasCoordinates,
                                ))
                                  Marker(
                                    point: _point(order.pickup),
                                    width: 48,
                                    height: 48,
                                    child: _opportunity(order),
                                  ),
                                if (selected != null &&
                                    selected.handover.hasCoordinates)
                                  Marker(
                                    point: _point(selected.handover),
                                    width: 48,
                                    height: 48,
                                    child: Tooltip(
                                      message:
                                          'Handover: ${selected.handover.name}',
                                      child: const Icon(
                                        Icons.flag_circle_rounded,
                                        color: AppColors.lime,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, bounds) => InteractiveViewer(
                            transformationController: _transform,
                            minScale: 1,
                            maxScale: 3,
                            child: Stack(
                              children: [
                                RouteCanvas(height: height, showLabels: true),
                                for (var i = 0; i < widget.orders.length; i++)
                                  Positioned(
                                    left:
                                        (bounds.maxWidth - 56) *
                                        (.76 - (i % 4) * .18),
                                    top: height * (.25 + (i % 4) * .15),
                                    width: 48,
                                    height: 48,
                                    child: _opportunity(widget.orders[i]),
                                  ),
                                if (selected != null)
                                  Positioned(
                                    left:
                                        bounds.maxWidth *
                                            (selected.handover.name.contains(
                                                  'Ramanagara',
                                                )
                                                ? .39
                                                : .53) -
                                        20,
                                    top:
                                        height *
                                            (selected.handover.name.contains(
                                                  'Ramanagara',
                                                )
                                                ? .70
                                                : .56) -
                                        20,
                                    width: 40,
                                    height: 40,
                                    child: Tooltip(
                                      message:
                                          'Handover: ${selected.handover.name}',
                                      child: const Icon(
                                        Icons.flag_circle_rounded,
                                        size: 38,
                                        color: AppColors.lime,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BENGALURU → MYSURU',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _streetTiles
                                ? 'Demo coordinates · Simulated route'
                                : 'Offline diagram · Not to scale',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_streetTiles && !_loaded)
                  const Positioned(
                    bottom: 14,
                    left: 14,
                    right: 14,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (!_streetTiles)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: IconButton.filledTonal(
                      tooltip: 'Reset route view',
                      onPressed: () => _transform.value = Matrix4.identity(),
                      icon: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _streetTiles
                    ? '© OpenStreetMap contributors\nopenstreetmap.org/copyright'
                    : 'Pinch to explore · Tap a parcel marker',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'Street tiles',
              child: Switch(
                value: _streetTiles,
                onChanged: coordinatesAvailable ? _toggle : null,
              ),
            ),
          ],
        ),
        Text(
          _streetTiles
              ? 'Street tiles on · No live location, traffic or turn-by-turn directions.'
              : 'Street tiles off · Demo locations only. Enable tiles with the switch.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
