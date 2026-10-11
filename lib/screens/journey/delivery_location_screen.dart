import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/demo_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../data/mock_journeys.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/map_attribution.dart';

class DeliveryLocationScreen extends StatefulWidget {
  const DeliveryLocationScreen({
    super.key,
    this.initialPosition,
    this.initialCenter,
    required this.place,
    this.title = 'Delivery location',
  });
  final LatLng? initialPosition;
  final LatLng? initialCenter;
  final String place;
  final String title;
  @override
  State<DeliveryLocationScreen> createState() => _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState extends State<DeliveryLocationScreen> {
  final _map = MapController();
  LatLng? _selected;
  bool _tilesLoaded = false;
  bool _tileError = false;
  int _tileGeneration = 0;
  Timer? _tileTimeout;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPosition;
    _startTileTimeout();
  }

  @override
  void dispose() {
    _tileTimeout?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _startTileTimeout() {
    _tileTimeout?.cancel();
    _tileTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && !_tilesLoaded) setState(() => _tileError = true);
    });
  }

  void _tileReady() {
    if (_tilesLoaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tilesLoaded) return;
      _tileTimeout?.cancel();
      setState(() {
        _tilesLoaded = true;
        _tileError = false;
      });
    });
  }

  Future<void> _locate() async {
    final location = context.read<LocationProvider>();
    await location.locate();
    if (!mounted) return;
    if (location.result.state == LocationState.ready &&
        location.position != null) {
      final position = location.position!;
      setState(() => _selected = position);
      _map.move(position, 17);
    } else {
      showMessage(context, location.result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final locating =
        context.watch<LocationProvider>().result.state == LocationState.loading;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.place, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Tap the map to mark the exact place. You can move the map and zoom in before choosing.',
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 340,
                  child: FlutterMap(
                    key: const ValueKey('delivery-location-map'),
                    mapController: _map,
                    options: MapOptions(
                      initialCenter:
                          _selected ?? widget.initialCenter ?? kochiCenter,
                      initialZoom:
                          _selected == null && widget.initialCenter == null
                          ? 13
                          : 16,
                      minZoom: 2,
                      maxZoom: 19,
                      backgroundColor: colors.surface,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, position) => setState(
                        () => _selected = LatLng(
                          position.latitude,
                          (position.longitude + 180) % 360 - 180,
                        ),
                      ),
                    ),
                    children: [
                      TileLayer(
                        key: ValueKey(_tileGeneration),
                        urlTemplate: DemoConfig.tileUrl,
                        userAgentPackageName: 'com.app',
                        maxNativeZoom: 19,
                        tileBuilder: (_, tile, image) {
                          if (image.imageInfo != null && !image.loadError) {
                            _tileReady();
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
                      if (_selected != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selected!,
                              width: 48,
                              height: 48,
                              child: Semantics(
                                key: const ValueKey('delivery-location-pin'),
                                label: 'Selected delivery location',
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.canvas,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: colors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const MapAttribution(),
                    ],
                  ),
                ),
              ),
              if (!_tilesLoaded && !_tileError) ...[
                const SizedBox(height: 12),
                const Text('Loading map…'),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: locating ? null : _locate,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      locating ? 'Finding location…' : 'Use my location',
                    ),
                  ),
                  if (_selected != null)
                    TextButton.icon(
                      onPressed: () => _map.move(_selected!, 17),
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Show pin'),
                    ),
                ],
              ),
              if (_tileError) ...[
                const SizedBox(height: 12),
                const Notice(
                  'The map could not fully load. Retry, use your current location, or go back and choose a suggested stop.',
                  warning: true,
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tilesLoaded = false;
                    _tileError = false;
                    _tileGeneration++;
                    _startTileTimeout();
                  }),
                  child: const Text('Retry map'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _selected == null
                    ? 'Choose a point on the map to continue.'
                    : 'Location selected. Check the pin before saving.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.check),
                  label: const Text('Use this location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
