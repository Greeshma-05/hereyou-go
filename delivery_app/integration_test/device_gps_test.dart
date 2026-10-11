import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:route_rescue/data/fulfillment_repository.dart';
import 'package:routerescue_partner/live/delivery_app.dart';
import 'package:routerescue_partner/live/delivery_state.dart';

// Native Android GPS is real; this repository records calls locally only.
class LocalGpsRepository extends Fake implements FulfillmentRepository {
  final calls = <Map<String, dynamic>>[];
  @override
  Stream<Map<String, dynamic>?> courier(String uid) =>
      Stream.value({'name': 'GPS check'});
  @override
  Stream<List<Map<String, dynamic>>> ordersFor(String field, String uid) =>
      Stream.value([]);
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add({'action': action, ...data});
    return action == 'nearby' ? {'offers': <dynamic>[]} : {};
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native GPS supplies the displayed and published partner coordinates',
    (tester) async {
      expect(const bool.fromEnvironment('GPS_DEVICE_TEST'), isTrue);
      final api = LocalGpsRepository();
      // Use the default production LocationService, not FixedLocation.
      final state = DeliveryState(api, 'local-gps-check');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: state,
                  builder: (_, _) => DeliveryLocationCard(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await state.refreshLocation().timeout(const Duration(seconds: 40));
      debugPrint(
        "Native GPS acquisition completed: ${state.error ?? state.location?.message}",
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.error, isNull);
      expect(state.location!.position!.latitude, closeTo(11.25, .001));
      expect(state.location!.position!.longitude, closeTo(75.78, .001));
      expect(state.location!.accuracyMeters!, lessThanOrEqualTo(150));
      expect(state.online, isFalse);
      expect(api.calls, isEmpty);
      expect(find.text('Last reading: 11.25000, 75.78000'), findsOneWidget);
      await state.setOnline(true).timeout(const Duration(seconds: 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.error, isNull);
      expect(state.locationSyncedAt, isNotNull);
      final presence = api.calls.firstWhere((c) => c['online'] == true);
      expect(presence['location']['latitude'], closeTo(11.25, .001));
      expect(presence['location']['longitude'], closeTo(75.78, .001));
      expect(
        find.text('GPS synced · nearby shops can find you'),
        findsOneWidget,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('delivery-native-gps');
      state.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
