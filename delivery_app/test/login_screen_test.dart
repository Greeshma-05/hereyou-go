import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/core/theme/app_theme.dart';
import 'package:routerescue_partner/core/utils/login_validators.dart';
import 'package:routerescue_partner/screens/auth/login_screen.dart';

void main() {
  Future<void> render(
    WidgetTester tester, {
    Future<void> Function()? onDemo,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(onEnterDemo: onDemo ?? () async {}),
      ),
    );
  }

  Future<void> tapLogin(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Login');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  test('email validation trims whitespace and rejects malformed addresses', () {
    for (final email in [
      '',
      ' ',
      'partner',
      'partner@',
      '@example.com',
      'partner@example',
      'a b@example.com',
    ]) {
      expect(LoginValidators.email(email), isNotNull);
    }
    expect(LoginValidators.email('  partner+demo@example.co.in  '), isNull);
    expect(LoginValidators.password(''), isNotNull);
    expect(LoginValidators.password('   '), isNotNull);
    expect(LoginValidators.password('example-password'), isNull);
  });

  testWidgets('form shows inline errors and password can be shown and hidden', (
    tester,
  ) async {
    await render(tester);
    await tapLogin(tester);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'invalid',
    );
    await tapLogin(tester);
    expect(
      find.text('Enter a valid email, such as partner@example.com.'),
      findsOneWidget,
    );

    final password = find.byKey(const ValueKey('login-password'));
    await tester.ensureVisible(password);
    await tester.enterText(password, 'test-password');
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: password, matching: find.byType(TextField)),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: password, matching: find.byType(TextField)),
          )
          .obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: password, matching: find.byType(TextField)),
          )
          .obscureText,
      isTrue,
    );
  });

  testWidgets(
    'standard Login loads, trims email, explains unavailable auth and never enters demo',
    (tester) async {
      var demoEntries = 0;
      await render(
        tester,
        onDemo: () async {
          demoEntries++;
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        '  partner@example.com  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'test-password',
      );
      await tapLogin(tester);
      expect(find.text('Checking sign-in'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-email')))
            .controller!
            .text,
        'partner@example.com',
      );
      final demoButton = find.widgetWithText(FilledButton, 'Try Demo Mode');
      expect(tester.widget<FilledButton>(demoButton).onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.textContaining('No sign-in occurred'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(demoEntries, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-password')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'demo needs no credentials, blocks repeated taps, and recovers from entry errors',
    (tester) async {
      var attempts = 0;
      await render(
        tester,
        onDemo: () async {
          attempts++;
          if (attempts == 1) throw StateError('Initialization failed');
        },
      );
      var button = find.widgetWithText(FilledButton, 'Try Demo Mode');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Opening demo'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Login'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Opening demo'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(
        find.text('Could not open Demo Mode. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Enter your email address.'), findsNothing);

      button = find.widgetWithText(FilledButton, 'Try Demo Mode');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        find.text('Could not open Demo Mode. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'disposing during the simulated operation does not navigate later',
    (tester) async {
      var entries = 0;
      await render(
        tester,
        onDemo: () async {
          entries++;
        },
      );
      final button = find.widgetWithText(FilledButton, 'Try Demo Mode');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      expect(entries, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
