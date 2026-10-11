import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../models/delivery_status.dart';
import '../../providers/session_scope.dart';
import '../../services/mock_partner_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/roo_tip.dart';

class SafePassScreen extends StatefulWidget {
  const SafePassScreen({required this.orderId, super.key});
  final String orderId;
  @override
  State<SafePassScreen> createState() => _SafePassScreenState();
}

class _SafePassScreenState extends State<SafePassScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter the six-digit demo code.');
      return;
    }
    final repo = SessionScope.repositoryOf(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    try {
      repo.verifyHandover(widget.orderId, _code.text);
    } on DemoActionException catch (error) {
      _error = error.message;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = SessionScope.repositoryOf(context).order(widget.orderId);
    final verified =
        order.status == DeliveryStatus.handoverConfirmed ||
        order.status == DeliveryStatus.delivered;
    final canVerify = order.status == DeliveryStatus.readyForHandover;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('SafePass')),
      body: SafeArea(
        child: AppPage(
          storageId: 'safe-pass',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: .9, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: verified ? AppColors.lime : AppColors.mintTint,
                      border: Border.all(color: AppColors.lime),
                    ),
                    child: Icon(
                      verified
                          ? Icons.check_rounded
                          : Icons.verified_user_outlined,
                      size: 44,
                      color: verified ? AppColors.background : AppColors.lime,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                verified
                    ? 'A safe handover.\nA happier journey.'
                    : 'One small code.\nOne confident handover.',
                textAlign: TextAlign.center,
                style: text.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                '${order.id} · ${order.traveler}\n${order.handover.name}',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              if (verified) ...[
                const RooTip(
                  title: 'Handover verified',
                  message: 'Nice work. Return to your mission and complete the delivery to record the demo reward.',
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Return to active mission',
                  onPressed: () => Navigator.pop(context),
                ),
              ] else if (canVerify)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('safepass-code'),
                        controller: _code,
                        readOnly: _busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onSubmitted: (_) => _verify(),
                        decoration: InputDecoration(
                          labelText: 'Six-digit demo code',
                          prefixIcon: const Icon(Icons.password_rounded),
                          errorText: _error,
                        ),
                        style: text.headlineSmall?.copyWith(letterSpacing: 6),
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Verify handover',
                        loadingLabel: 'Checking demo code',
                        isLoading: _busy,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        'Demo code for ${order.id}: ${order.demoCode}',
                        style: text.titleSmall?.copyWith(color: AppColors.lime),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Offline simulation only. This is not a secure OTP. Real code delivery, expiry and replay protection require a trusted backend.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const RooTip(
                  title: 'Finish the journey steps first',
                  message: 'Confirm pickup and arrival at the handover point before opening SafePass.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
