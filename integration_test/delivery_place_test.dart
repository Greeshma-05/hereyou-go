import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/delivery_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: Here You Go typed delivery address and pin through checkout',
    (tester) async {
      bool converted = false;
      await runDeliveryFlow(
        tester,
        capture: (name) async {
          if (!converted) {
            await binding.convertFlutterSurfaceToImage();
            converted = true;
          }
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
          await binding.takeScreenshot(name);
        },
      );
    },
  );
}
