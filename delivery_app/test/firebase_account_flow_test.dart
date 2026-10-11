import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routerescue_partner/app.dart';
import 'package:routerescue_partner/models/firebase_account.dart';
import 'package:routerescue_partner/providers/session_scope.dart';
import 'package:routerescue_partner/screens/app_shell.dart';
import 'package:routerescue_partner/screens/auth/firebase_account_screen.dart';
import 'package:routerescue_partner/screens/auth/login_screen.dart';
import 'package:routerescue_partner/services/account_gateway.dart';
import 'package:routerescue_partner/services/firebase_account_gateway.dart';

import 'helpers/memory_onboarding_store.dart';
import 'helpers/test_account_gateway.dart';

void main() {
  Future<void> render(WidgetTester tester, AccountGateway gateway) async {
    await tester.pumpWidget(
      RouteRescuePartnerApp(
        onboardingStore: MemoryOnboardingStore(completed: true),
        accountGateway: gateway,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillCredentials(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      '  partner@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'example-password',
    );
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> changeMode(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('auth-change-mode'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
  }

  Future<void> openAccount(WidgetTester tester) async {
    await openProfile(tester);
    final details = find.widgetWithText(ListTile, 'Account details');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
  }

  testWidgets('signup has no demo panel and login retains guest access', (
    tester,
  ) async {
    await render(tester, TestAccountGateway());
    expect(find.text('Try Demo Mode'), findsOneWidget);
    await changeMode(tester);
    expect(find.text('Try Demo Mode'), findsNothing);
    expect(find.text('Take a look around'), findsNothing);
    expect(
      find.text('Demo access does not authenticate a real account.'),
      findsNothing,
    );
    await changeMode(tester);
    expect(find.text('Try Demo Mode'), findsOneWidget);
  });

  Future<void> fillSignup(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('signup-name')),
      '  New Partner  ',
    );
    await fillCredentials(tester);
    await tester.enterText(
      find.byKey(const ValueKey('signup-confirm-password')),
      'example-password',
    );
  }

  testWidgets(
    'signup validates name, email, password length and confirmation before contacting Firebase',
    (tester) async {
      final gateway = TestAccountGateway();
      await render(tester, gateway);
      await changeMode(tester);
      await tap(tester, 'Sign up');
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('signup-name')),
        'Partner',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'bad-email',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        '123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-confirm-password')),
        '456',
      );
      await tap(tester, 'Sign up');
      expect(find.text('Use at least 6 characters.'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(find.textContaining('Enter a valid email'), findsOneWidget);
      expect(gateway.signUps, 0);
    },
  );

  testWidgets(
    'signup trims inputs, connects the account, and permits logout then login',
    (tester) async {
      final gateway = TestAccountGateway();
      await render(tester, gateway);
      await changeMode(tester);
      await fillSignup(tester);
      await tap(tester, 'Sign up');
      expect(gateway.signUps, 1);
      expect(gateway.email, 'partner@example.com');
      expect(gateway.name, 'New Partner');
      expect(find.byType(FirebaseAccountScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('New Partner'), findsOneWidget);
      await openProfile(tester);
      await tap(tester, 'Sign out');
      await fillCredentials(tester);
      await tap(tester, 'Login');
      expect(gateway.signIns, 1);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Sample deliveries · Offline'), findsOneWidget);
    },
  );

  testWidgets(
    'signup blocks repeat actions and back while pending, then explains duplicate email',
    (tester) async {
      final gateway = TestAccountGateway()
        ..pendingSignUp = Completer<FirebaseAccount>();
      await render(tester, gateway);
      await changeMode(tester);
      await fillSignup(tester);
      final submit = find.widgetWithText(FilledButton, 'Sign up');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Creating account'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Try Demo Mode'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('auth-change-mode')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const ValueKey('signup-name')), findsOneWidget);
      gateway.pendingSignUp!.completeError(
        AccountFailure(
          FirebaseAccountGateway.authErrorMessage('email-already-in-use'),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.signUps, 1);
      expect(
        find.textContaining('An account already uses this email'),
        findsOneWidget,
      );
      for (final key in ['login-password', 'signup-confirm-password']) {
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey(key)))
              .controller!
              .text,
          isEmpty,
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('signup-name')), findsNothing);
      expect(find.text('Welcome, partner.'), findsOneWidget);
    },
  );

  testWidgets(
    'profile setup failure after signup does not block the delivery tools',
    (tester) async {
      final gateway = TestAccountGateway()
        ..pendingSignUp = Completer<FirebaseAccount>();
      await render(tester, gateway);
      await changeMode(tester);
      await fillSignup(tester);
      final submit = find.widgetWithText(FilledButton, 'Sign up');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      gateway.pendingSignUp!.complete(
        const FirebaseAccount(
          uid: 'new-partner',
          email: 'partner@example.com',
          setupMessage: 'Account created. Profile setup needs attention.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      await openProfile(tester);
      expect(
        find.text('Account created. Profile setup needs attention.'),
        findsOneWidget,
      );
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets(
    'password recovery validates only email, prevents repeats and displays a neutral result',
    (tester) async {
      final gateway = TestAccountGateway()..pendingReset = Completer<void>();
      await render(tester, gateway);
      var reset = find.widgetWithText(TextButton, 'Forgot password?');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(gateway.resetRequests, 0);
      expect(find.text('Enter your email address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        ' partner@example.com ',
      );
      reset = find.widgetWithText(TextButton, 'Forgot password?');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Login'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Requesting reset link...'),
            )
            .onPressed,
        isNull,
      );
      gateway.pendingReset!.complete();
      await tester.pumpAndSettle();
      expect(gateway.resetRequests, 1);
      expect(gateway.email, 'partner@example.com');
      expect(
        find.textContaining('If this email has a password account'),
        findsOneWidget,
      );
      expect(find.text('Enter your password.'), findsNothing);
      expect(gateway.signIns, 0);
    },
  );

  testWidgets('signup supports a small phone, large text and the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    await render(tester, TestAccountGateway());
    await changeMode(tester);
    await fillSignup(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Sign up');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Firebase auth errors are actionable and do not expose raw exceptions',
    () {
      expect(
        FirebaseAccountGateway.authErrorMessage('wrong-password'),
        FirebaseAccountGateway.authErrorMessage('user-not-found'),
      );
      expect(
        FirebaseAccountGateway.authErrorMessage('network-request-failed'),
        contains('connection'),
      );
      expect(
        FirebaseAccountGateway.authErrorMessage('operation-not-allowed'),
        contains('not enabled'),
      );
      expect(
        FirebaseAccountGateway.authErrorMessage('unknown-server-details'),
        'Sign-in failed. Please try again.',
      );
    },
  );

  testWidgets(
    'real sign-in opens all tabs with real identity and labeled sample data',
    (tester) async {
      final gateway = TestAccountGateway();
      await render(tester, gateway);
      await fillCredentials(tester);
      await tap(tester, 'Login');
      expect(gateway.signIns, 1);
      expect(gateway.email, 'partner@example.com');
      expect(find.byType(FirebaseAccountScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Sample deliveries · Offline'), findsOneWidget);
      expect(find.text('Test Partner'), findsOneWidget);
      final session = SessionScope.maybeOf(
        tester.element(find.byType(AppShell)),
      )!;
      expect(session.account?.uid, 'partner-1');
      expect(session.isAuthenticated, isTrue);
      session.repository.setOnline(true);
      session.repository.setPreferences(hapticsEnabled: false);
      for (final (key, index) in [
        ('nav-requests', 1),
        ('nav-route', 2),
        ('nav-earnings', 3),
        ('nav-profile', 4),
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
        expect(
          SessionScope.maybeOf(tester.element(find.byType(AppShell))),
          same(session),
        );
      }
      expect(find.text('Test Partner'), findsOneWidget);
      expect(find.text('partner@example.com'), findsOneWidget);
      expect(find.text('SIGNED IN'), findsOneWidget);
      expect(find.text('DEMO ACCOUNT'), findsNothing);
      expect(gateway.profileReads, 0);
      await tap(tester, 'Sign out');
      expect(gateway.signOuts, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'pending sign-in blocks repeats and demo entry; failure clears password',
    (tester) async {
      final gateway = TestAccountGateway()
        ..pendingSignIn = Completer<FirebaseAccount>();
      await render(tester, gateway);
      await fillCredentials(tester);
      final button = find.widgetWithText(FilledButton, 'Login');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Try Demo Mode'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Checking sign-in'),
            )
            .onPressed,
        isNull,
      );
      gateway.pendingSignIn!.completeError(
        const AccountFailure('The email or password is incorrect.'),
      );
      await tester.pumpAndSettle();
      expect(gateway.signIns, 1);
      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-password')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byType(AppShell), findsNothing);
    },
  );

  testWidgets(
    'pending logout blocks navigation and the next account starts with fresh delivery state',
    (tester) async {
      final gateway = TestAccountGateway()..pendingSignOut = Completer<void>();
      await render(tester, gateway);
      await fillCredentials(tester);
      await tap(tester, 'Login');
      final oldSession = SessionScope.maybeOf(
        tester.element(find.byType(AppShell)),
      )!;
      oldSession.repository.setOnline(true);
      oldSession.repository.setPreferences(notificationsEnabled: false);
      await openProfile(tester);
      final logout = find.widgetWithText(FilledButton, 'Sign out');
      await tester.ensureVisible(logout);
      await tester.pumpAndSettle();
      await tester.tap(logout);
      await tester.pump();
      expect(gateway.signOuts, 1);
      expect(find.text('Signing out'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Signing out'),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      gateway.pendingSignOut!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      gateway.signedInAccount = const FirebaseAccount(
        uid: 'partner-2',
        email: 'second@example.com',
        name: 'Second Partner',
      );
      await fillCredentials(tester);
      await tap(tester, 'Login');
      final newSession = SessionScope.maybeOf(
        tester.element(find.byType(AppShell)),
      )!;
      expect(newSession.account!.uid, 'partner-2');
      expect(newSession.repository, isNot(same(oldSession.repository)));
      expect(newSession.isOnline, isFalse);
      expect(newSession.repository.partner.notificationsEnabled, isTrue);
      expect(newSession.repository.todayEarningsPaise, 0);
      expect(find.text('Second Partner'), findsOneWidget);
    },
  );

  testWidgets(
    'optional account details retry errors and Back preserves the signed-in profile tab',
    (tester) async {
      final gateway = TestAccountGateway()..rejectProfile = true;
      await render(tester, gateway);
      await fillCredentials(tester);
      await tap(tester, 'Login');
      await openAccount(tester);
      expect(find.text('Profile access denied.'), findsOneWidget);
      gateway.rejectProfile = false;
      final reload = find.text('Reload profile');
      await tester.ensureVisible(reload);
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(find.text('Test Partner'), findsOneWidget);
      expect(gateway.profileReads, 2);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(gateway.signOuts, 0);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      gateway.rejectSignOut = true;
      await tap(tester, 'Sign out');
      expect(find.text('Could not sign out. Please retry.'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      gateway.rejectSignOut = false;
      await tap(tester, 'Sign out');
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'entering the demo signs out a previous Firebase session without reading profiles',
    (tester) async {
      final gateway = TestAccountGateway();
      await render(tester, gateway);
      await tap(tester, 'Try Demo Mode');
      expect(gateway.signOuts, 1);
      expect(gateway.signIns, 0);
      expect(gateway.profileReads, 0);
      expect(find.byType(AppShell), findsOneWidget);
    },
  );

  testWidgets('account and profile error fit a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final gateway = TestAccountGateway()..rejectProfile = true;
    await render(tester, gateway);
    await fillCredentials(tester);
    await tap(tester, 'Login');
    await openAccount(tester);
    expect(find.text('Profile access denied.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, 'Sign out');
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
