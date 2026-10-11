import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants/demo_config.dart';
import '../models/delivery_route.dart';

class DeliveryRoutingService {
  DeliveryRoutingService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? DemoConfig.routingUrl;
  final http.Client _client;
  final String _baseUrl;
  String get host => Uri.parse(_baseUrl).host;
  bool _disposed = false;
  static Future<void> _queue = Future.value();
  static DateTime? _lastStarted;

  // The shared preview service allows at most one request per second.
  static Future<void> _reserveRequest() {
    final next = _queue.then((_) async {
      final elapsed = _lastStarted == null
          ? const Duration(seconds: 2)
          : DateTime.now().difference(_lastStarted!);
      const interval = Duration(milliseconds: 1100);
      if (elapsed < interval) await Future<void>.delayed(interval - elapsed);
      _lastStarted = DateTime.now();
    });
    _queue = next;
    return next;
  }

  Future<DeliveryRoute> route(LatLng shop, LatLng delivery) async {
    if (!validCoordinates(shop.latitude, shop.longitude) ||
        !validCoordinates(delivery.latitude, delivery.longitude)) {
      throw const FormatException('Invalid delivery coordinates');
    }
    await _reserveRequest();
    if (_disposed) throw StateError('Route request cancelled');
    final base = Uri.parse(_baseUrl);
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty) {
      throw const FormatException('An HTTPS routing service is required');
    }
    String coordinate(LatLng p) =>
        '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}';
    final uri = base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/$'), '')}/route/v1/driving/${coordinate(shop)};${coordinate(delivery)}',
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'radiuses': '250;250',
        'generate_hints': 'false',
      },
    );
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (!kIsWeb)
              'User-Agent':
                  'HereYouGo/0.1 (com.app; Flutter delivery route preview)',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.bodyBytes.length > 4 * 1024 * 1024) {
      throw const FormatException('Routing service unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] == 'NoSegment' || data['code'] == 'NoRoute') {
      throw const RoutingException(
        'No driving route was found near these pins. The delivery address and pins are still available.',
      );
    }
    if (response.statusCode != 200) {
      throw const FormatException('Routing service unavailable');
    }
    return DeliveryRoute.fromOsrm(data);
  }

  void dispose() {
    _disposed = true;
    _client.close();
  }
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
}
