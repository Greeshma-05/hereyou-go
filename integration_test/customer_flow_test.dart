import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/demo_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: customer journey through demo handover and map browsing',
    (tester) async {
      await runDemoFlow(tester);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('android-home');
      await tapVisible(tester, find.text('Explore'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('KOCHI · NEARBY SHOPS'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('The Travellers’ Kitchen'));
      expect(find.text('ALONG YOUR ROUTE'), findsOneWidget);
      await binding.takeScreenshot('android-vendor-sheet');
      await tapVisible(tester, find.text('Browse essentials'));
      expect(find.text('Pick your essentials'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Show list'));
      await tester.enterText(find.byType(TextField), 'no-matching-product');
      await tester.pumpAndSettle();
      expect(find.text('Nothing here just yet'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Clear search'));
      await tapVisible(tester, find.byTooltip('Show map'));
      await tester.pump(const Duration(seconds: 2));
      await binding.takeScreenshot('android-explore');
      expect(tester.takeException(), isNull);
    },
  );
}
