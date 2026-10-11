import 'package:flutter/material.dart';
import 'package:route_rescue/core/theme/app_theme.dart';
import 'package:route_rescue/data/merchant_repository.dart';
import 'package:route_rescue/widgets/common.dart';
import '../state/merchant_state.dart';

class VendorAuthScreen extends StatefulWidget {
  const VendorAuthScreen({super.key, required this.repository});
  final MerchantRepository repository;
  @override
  State<VendorAuthScreen> createState() => _VendorAuthScreenState();
}

class _VendorAuthScreenState extends State<VendorAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = true;
  bool _busy = false;
  bool _show = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signup) {
        await widget.repository.signUp(_email.text, _password.text);
      } else {
        await widget.repository.signIn(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = merchantError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.resetPassword(_email.text);
      if (mounted) {
        setState(
          () => _error =
              'If this email has an account, a password reset link will be sent.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = merchantError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Here You Go Vendor')),
    body: SafeArea(
      child: PageBody(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(size: 64),
                const SizedBox(height: 24),
                Text(
                  'Your shop.\nTheir next stop.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Manage your catalog and reach travelers near your shop.',
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('Register'),
                      selected: _signup,
                      labelStyle: TextStyle(
                        color: _signup
                            ? AppTheme.colors(context).onAccent
                            : AppTheme.colors(context).ink,
                      ),
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _signup = true),
                    ),
                    ChoiceChip(
                      label: const Text('Log in'),
                      selected: !_signup,
                      labelStyle: TextStyle(
                        color: !_signup
                            ? AppTheme.colors(context).onAccent
                            : AppTheme.colors(context).ink,
                      ),
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _signup = false),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (s) =>
                      s != null &&
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(s.trim())
                      ? null
                      : 'Enter a valid email address.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: !_show,
                  autofillHints: [
                    _signup
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _show ? 'Hide password' : 'Show password',
                      onPressed: () => setState(() => _show = !_show),
                      icon: Icon(
                        _show
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (s) => s != null && s.length >= (_signup ? 8 : 1)
                      ? null
                      : 'Use at least 8 characters.',
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Connecting…'
                          : _signup
                          ? 'Create vendor account'
                          : 'Log in to your shop',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _reset,
                  child: const Text('Forgot password?'),
                ),
                if (_error != null) Notice(_error!, warning: true),
                const SizedBox(height: 16),
                const Notice(
                  'Already use Here You Go? Log in with the same email and password, then register your shop.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
