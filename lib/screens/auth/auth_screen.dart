import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/accessibility_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _obscure = true;
  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final session = context.read<SessionProvider>();
    final success = await session.authenticate(
      signup: _signup,
      name: _name.text.trim(),
      email: _contact.text.trim(),
      password: _password.text,
    );
    if (mounted && success) _password.clear();
  }

  Future<void> _resetPassword() async {
    if (emailError(_contact.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }
    final sent = await context.read<SessionProvider>().resetPassword(
      _contact.text,
    );
    if (mounted && sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'If an account exists, a password reset email has been sent.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 30),
                const Row(
                  children: [
                    AppLogo(size: 56),
                    Spacer(),
                    AccessibilityButton(),
                  ],
                ),
                SizedBox(height: 30),
                StatusBadge(text: 'YOUR JOURNEY STARTS HERE'),
                SizedBox(height: 16),
                Text(
                  _signup
                      ? 'A better journey\nstarts here.'
                      : 'Welcome aboard.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 10),
                Text(
                  _signup
                      ? 'Make yourself at home.'
                      : 'Your essentials are just a few taps away.',
                  style: TextStyle(color: AppTheme.colors(context).muted),
                ),
                SizedBox(height: 28),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text('Log in')),
                    ButtonSegment(value: true, label: Text('Sign up')),
                  ],
                  selected: {_signup},
                  onSelectionChanged: (value) => setState(() {
                    _signup = value.first;
                    _form.currentState?.reset();
                  }),
                ),
                SizedBox(height: 24),
                if (_signup) ...[
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: requiredField,
                    maxLength: 60,
                  ),
                  SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _contact,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: emailError,
                  maxLength: 120,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => _signup
                      ? ((value?.length ?? 0) < 8
                            ? 'Use at least 8 characters.'
                            : null)
                      : ((value?.isEmpty ?? true)
                            ? 'Enter your password.'
                            : null),
                  onFieldSubmitted: (_) => _submit(),
                ),
                SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: session.busy ? null : _submit,
                    child: Text(
                      session.busy
                          ? 'Connecting…'
                          : _signup
                          ? 'Create profile'
                          : 'Continue',
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: session.busy ? null : session.enterGuest,
                    icon: Icon(Icons.explore_outlined),
                    label: Text('Continue as guest'),
                  ),
                ),
                SizedBox(height: 24),
                if (!_signup && session.cloudAvailable)
                  TextButton(
                    onPressed: session.busy ? null : _resetPassword,
                    child: Text('Forgot password?'),
                  ),
                if (session.error != null) ...[
                  Notice(session.error!, warning: true),
                  SizedBox(height: 12),
                ],
                Notice(
                  session.cloudAvailable
                      ? 'Sign in to save your profile, orders and travel history across devices. Guest activity stays in this session.'
                      : 'Account sign-in is not connected yet. Guest browsing is available; guest activity stays in this session.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
