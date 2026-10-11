import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/login_validators.dart';
import '../../services/account_gateway.dart';
import '../../widgets/app_brand.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/cinematic_background.dart';

enum _LoginAction { credentials, demo, resetPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onEnterDemo,
    this.onSignIn,
    this.onCreateAccount,
    this.onResetPassword,
    this.signInDescription = 'Firebase sign-in is not configured for this build. Demo Mode is available.',
    super.key,
  });

  final Future<void> Function() onEnterDemo;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String name, String email, String password)?
  onCreateAccount;
  final Future<void> Function(String email)? onResetPassword;
  final String signInDescription;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageKey = GlobalKey();
  bool _obscurePassword = true;
  bool _creatingAccount = false;
  _LoginAction? _processing;
  String? _message;
  bool _messageIsError = true;

  bool get _busy => _processing != null;

  void _changeMode() {
    if (_busy) return;
    final email = _emailController.text;
    _formKey.currentState?.reset();
    _emailController.text = email;
    _passwordController.clear();
    _confirmPasswordController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _creatingAccount = !_creatingAccount;
      _obscurePassword = true;
      _message = null;
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messageContext = _messageKey.currentContext;
      if (!mounted || messageContext == null) return;
      Scrollable.ensureVisible(
        messageContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
    });
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final error = LoginValidators.email(email);
    if (error != null) {
      _showMessage(error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _processing = _LoginAction.resetPassword;
      _message = null;
    });
    try {
      await widget.onResetPassword!(email);
      if (mounted) {
        _showMessage(
          'If this email has a password account, a reset link has been sent. Check your inbox and spam folder, then return to Login.',
          isError: false,
        );
      }
    } on AccountFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not request a password reset. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    _emailController.text = _emailController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _processing = _LoginAction.credentials;
      _message = null;
    });

    try {
      if (_creatingAccount) {
        if (widget.onCreateAccount == null) {
          throw const AccountFailure(
            'Firebase account creation is not configured for this build. Choose Try Demo Mode.',
          );
        }
        await widget.onCreateAccount!(
          _nameController.text.trim(),
          _emailController.text,
          _passwordController.text,
        );
      } else if (widget.onSignIn == null) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        throw const AccountFailure(
          'Firebase sign-in is not configured for this build. No sign-in occurred. Choose Try Demo Mode.',
        );
      } else {
        await widget.onSignIn!(_emailController.text, _passwordController.text);
      }
    } on AccountFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          _creatingAccount
              ? 'Could not create your account. Please try again.'
              : 'Sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        TextInput.finishAutofillContext(shouldSave: false);
        setState(() => _processing = null);
      }
    }
  }

  Future<void> _enterDemo() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _processing = _LoginAction.demo;
      _message = null;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      _passwordController.clear();
      _confirmPasswordController.clear();
      TextInput.finishAutofillContext(shouldSave: false);
      await widget.onEnterDemo();
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open Demo Mode. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope<Object?>(
      canPop: !_creatingAccount && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _creatingAccount && !_busy) _changeMode();
      },
      child: Scaffold(
        body: CinematicBackground(
          child: SafeArea(
            child: AppPage(
              storageId: 'login',
              controller: _scrollController,
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppBrand(),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'YOUR NEXT CHAPTER',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        header: true,
                        child: Text(
                          _creatingAccount
                              ? 'Create your account.'
                              : 'Welcome, partner.',
                          style: textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _creatingAccount
                            ? 'One RouteRescue account. Sign up with your email and a password you choose.'
                            : 'A little care can take someone a long way. Your journey starts here.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_creatingAccount) ...[
                              TextFormField(
                                key: const ValueKey('signup-name'),
                                controller: _nameController,
                                readOnly: _busy,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator: LoginValidators.name,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 160,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            TextFormField(
                              key: const ValueKey('login-email'),
                              controller: _emailController,
                              readOnly: _busy,
                              keyboardType: TextInputType.emailAddress,
                              scrollPadding: const EdgeInsets.only(bottom: 160),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              enableSuggestions: false,
                              validator: LoginValidators.email,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'you@example.com',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              key: const ValueKey('login-password'),
                              controller: _passwordController,
                              readOnly: _busy,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              scrollPadding: const EdgeInsets.only(bottom: 160),
                              textInputAction: _creatingAccount
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: [
                                _creatingAccount
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              autocorrect: false,
                              enableSuggestions: false,
                              validator: _creatingAccount
                                  ? LoginValidators.newPassword
                                  : LoginValidators.password,
                              onFieldSubmitted: (_) {
                                if (_creatingAccount) {
                                  FocusScope.of(context).nextFocus();
                                } else {
                                  _login();
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  isSelected: !_obscurePassword,
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (_creatingAccount) ...[
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                key: const ValueKey('signup-confirm-password'),
                                controller: _confirmPasswordController,
                                readOnly: _busy,
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.visiblePassword,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 160,
                                ),
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                validator: (value) =>
                                    LoginValidators.confirmPassword(
                                      value,
                                      _passwordController.text,
                                    ),
                                onFieldSubmitted: (_) => _login(),
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            AppButton(
                              label: _creatingAccount ? 'Sign up' : 'Login',
                              loadingLabel: _creatingAccount
                                  ? 'Creating account'
                                  : 'Checking sign-in',
                              isLoading:
                                  _processing == _LoginAction.credentials,
                              onPressed: _busy ? null : _login,
                            ),
                            if (!_creatingAccount &&
                                widget.onResetPassword != null)
                              TextButton(
                                onPressed: _busy ? null : _resetPassword,
                                child: Text(
                                  _processing == _LoginAction.resetPassword
                                      ? 'Requesting reset link...'
                                      : 'Forgot password?',
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _creatingAccount
                                  ? 'Creates an account in RouteRescue. Delivery assignments require partner access. Already registered in the customer app? Use Login.'
                                  : widget.signInDescription,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              key: const ValueKey('auth-change-mode'),
                              onPressed: _busy ? null : _changeMode,
                              child: Text(
                                _creatingAccount
                                    ? 'Back to login'
                                    : 'Create account',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Semantics(
                          key: _messageKey,
                          liveRegion: true,
                          child: Text(
                            _message!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: _messageIsError
                                  ? AppColors.error
                                  : AppColors.lime,
                            ),
                          ),
                        ),
                      ],
                      if (!_creatingAccount) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppCard(
                          color: AppColors.mintTint,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.explore_outlined,
                                    color: AppColors.lime,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Take a look around',
                                      style: textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Explore as Demo Delivery Partner. No credentials needed. You will start offline.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppButton(
                                label: 'Try Demo Mode',
                                icon: Icons.arrow_forward_rounded,
                                loadingLabel: 'Opening demo',
                                isLoading: _processing == _LoginAction.demo,
                                onPressed: _busy ? null : _enterDemo,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Demo access does not authenticate a real account.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
