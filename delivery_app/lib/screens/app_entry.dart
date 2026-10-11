import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/demo_session.dart';
import '../models/firebase_account.dart';
import '../models/partner_session.dart';
import '../services/account_gateway.dart';
import '../providers/session_scope.dart';
import '../services/onboarding_store.dart';
import 'app_shell.dart';
import 'auth/login_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'splash/splash_screen.dart';

enum _EntryStage { splash, onboarding, login, shell }

class AppEntry extends StatefulWidget {
  const AppEntry({
    this.onboardingStore,
    this.accountGateway = const UnavailableAccountGateway(),
    super.key,
  });

  final OnboardingStore? onboardingStore;
  final AccountGateway accountGateway;

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late final OnboardingStore _store =
      widget.onboardingStore ?? LocalOnboardingStore();
  _EntryStage _stage = _EntryStage.splash;
  PartnerSession? _session;

  void _finishSplash(bool completed) {
    setState(
      () => _stage = completed ? _EntryStage.login : _EntryStage.onboarding,
    );
  }

  void _openLogin() => setState(() => _stage = _EntryStage.login);

  Future<void> _signIn(String email, String password) async {
    final account = await widget.accountGateway.signIn(email, password);
    await _openAccount(account);
  }

  Future<void> _createAccount(
    String name,
    String email,
    String password,
  ) async {
    final account = await widget.accountGateway.createAccount(
      name,
      email,
      password,
    );
    await _openAccount(account);
  }

  Future<void> _openAccount(FirebaseAccount account) async {
    if (!mounted || _stage != _EntryStage.login) {
      await widget.accountGateway.signOut();
      return;
    }
    setState(() {
      _session = PartnerSession(account: account);
      _stage = _EntryStage.shell;
    });
  }

  Future<void> _enterDemo() async {
    if (!mounted || _stage != _EntryStage.login) {
      throw StateError('Demo entry is only available from login.');
    }
    // A previous Firebase session must not leak into the offline demo.
    await widget.accountGateway.signOut();
    if (!mounted || _stage != _EntryStage.login) return;
    setState(() {
      _session = DemoSession();
      _stage = _EntryStage.shell;
    });
  }

  Future<void> _logout() async {
    if (!mounted || _stage != _EntryStage.shell) return;
    if (_session?.repository.activeMission != null) {
      throw const AccountFailure(
        'Finish the active delivery before logging out.',
      );
    }
    final oldSession = _session;
    if (oldSession?.isAuthenticated == true) {
      await widget.accountGateway.signOut();
    }
    if (!mounted || _session != oldSession) return;
    setState(() {
      _session = null;
      _stage = _EntryStage.login;
    });
    oldSession?.repository.dispose();
  }

  @override
  void dispose() {
    _session?.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = switch (_stage) {
      _EntryStage.splash => SplashScreen(
        store: _store,
        onFinished: _finishSplash,
      ),
      _EntryStage.onboarding => OnboardingScreen(
        store: _store,
        onCompleted: _openLogin,
      ),
      _EntryStage.login => LoginScreen(
        onEnterDemo: _enterDemo,
        onSignIn: _signIn,
        onCreateAccount: _createAccount,
        onResetPassword: widget.accountGateway.sendPasswordReset,
        signInDescription: widget.accountGateway.signInDescription,
      ),
      _EntryStage.shell => SessionScope(
        session: _session!,
        child: AppShell(
          onLogout: _logout,
          accountGateway: widget.accountGateway,
        ),
      ),
    };

    // Replace the entry content, so Back never exposes old login/onboarding screens.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlayStyle,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: KeyedSubtree(key: ValueKey(_stage), child: screen),
      ),
    );
  }
}
