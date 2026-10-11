import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/core/theme/app_theme.dart';
import 'package:routerescue_partner/widgets/app_button.dart';

void main() {
  testWidgets('button accepts taps only when enabled and not loading', (
    tester,
  ) async {
    var taps = 0;

    Future<void> render({bool loading = false, bool enabled = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton(
              label: 'Continue',
              onPressed: enabled ? () => taps++ : null,
              isLoading: loading,
              loadingLabel: 'Saving',
              icon: Icons.arrow_forward,
            ),
          ),
        ),
      );
    }

    await render();
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);

    await render(loading: true);
    expect(find.text('Saving'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);

    await render(enabled: false);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);

    await render();
    await tester.tap(find.byType(FilledButton));
    expect(taps, 2);
  });
}
