import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../data/courier_tracking_source.dart';
import '../models/delivery_route.dart';
import '../services/delivery_routing_service.dart';

class DeliveryMapProvider extends ChangeNotifier {
  DeliveryMapProvider({
    required this.reference,
    required this.shop,
    required this.delivery,
    DeliveryRoutingService? routing,
    CourierTrackingSource? tracking,
  }) : _routing = routing ?? DeliveryRoutingService(),
       tracking = tracking ?? const UnavailableCourierTracking() {
    _subscription = this.tracking
        .watch(reference)
        .listen(
          (fix) {
            if (_disposed) return;
            if (fix != null &&
                (!fix.isValid ||
                    fix.recordedAt.isAfter(
                      DateTime.now().add(const Duration(seconds: 30)),
                    ) ||
                    courier != null &&
                        fix.recordedAt.isBefore(courier!.recordedAt))) {
              return;
            }
            courier = fix;
            trackingError = false;
            notifyListeners();
          },
          onError: (Object _) {
            if (_disposed) return;
            trackingError = true;
            notifyListeners();
          },
          onDone: () {
            if (_disposed || !this.tracking.connected) return;
            trackingError = true;
            notifyListeners();
          },
        );
    if (this.tracking.connected) {
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!_disposed) notifyListeners();
      });
    }
  }
  final String reference;
  final LatLng? shop;
  final LatLng delivery;
  final DeliveryRoutingService _routing;
  final CourierTrackingSource tracking;
  StreamSubscription<CourierFix?>? _subscription;
  Timer? _timer;
  bool _disposed = false;
  bool loading = false;
  String? error;
  DeliveryRoute? roadRoute;
  CourierFix? courier;
  bool trackingError = false;
  String get routingHost => _routing.host;
  bool get courierLive =>
      tracking.connected &&
      !trackingError &&
      courier?.isFresh(DateTime.now()) == true;

  Future<void> loadRoute() async {
    if (_disposed || loading) return;
    if (shop == null) {
      error =
          'The shop location is unavailable. Your delivery pin is still shown.';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _routing.route(shop!, delivery);
      if (!_disposed) roadRoute = result;
    } on RoutingException catch (failure) {
      if (!_disposed) error = failure.message;
    } catch (_) {
      if (!_disposed) {
        error =
            'The road route could not load. Retry when connected. Your shop and delivery pins are still available.';
      }
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _timer?.cancel();
    _routing.dispose();
    super.dispose();
  }
}
