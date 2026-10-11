import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/onboarding_store.dart';
import '../../widgets/app_button.dart';
import '../../widgets/journey_illustration.dart';
import '../../widgets/onboarding_indicator.dart';
import 'onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.store,
    required this.onCompleted,
    super.key,
  });

  final OnboardingStore store;
  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;
  bool _saving = false;
  bool _changingPage = false;
  String? _error;

  static const _pages = [
    OnboardingPage(
      number: 1,
      caption: 'CONNECT THE JOURNEY',
      title: 'Every Delivery Starts a Journey',
      description: 'Receive delivery requests from nearby vendors and help travelers get what they need.',
      scene: JourneyScene.shopRoute,
    ),
    OnboardingPage(
      number: 2,
      caption: 'FIND YOUR WAY',
      title: 'Your Route, Your Mission',
      description: 'View pickup locations, handover points, and delivery progress in one place.',
      scene: JourneyScene.map,
    ),
    OnboardingPage(
      number: 3,
      caption: 'CARE AT EVERY STOP',
      title: 'Deliver with Confidence',
      description: 'Confirm pickups, verify handovers, and keep every delivery organized.',
      scene: JourneyScene.verified,
    ),
  ];

  Future<void> _goToPage(int page) async {
    if (_saving || _changingPage || !_pageController.hasClients) return;
    setState(() => _changingPage = true);
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pageController.jumpToPage(page);
      } else {
        await _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
    } finally {
      if (mounted) setState(() => _changingPage = false);
    }
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.complete().timeout(const Duration(seconds: 3));
      if (mounted) widget.onCompleted();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your progress. Try again, or continue without saving.';
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _index == 0 && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving && _index > 0) _goToPage(_index - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      if (_index > 0)
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: _saving || _changingPage
                              ? null
                              : () => _goToPage(_index - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48, height: 48),
                      const Spacer(),
                      TextButton(
                        onPressed: _saving ? null : _complete,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    allowImplicitScrolling: true,
                    physics: _saving
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    onPageChanged: (index) => setState(() => _index = index),
                    children: _pages,
                  ),
                ),
                // Keep recovery actions reachable when text or system insets grow.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.maxContentWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.compactPageInset,
                            AppSpacing.lg,
                            AppSpacing.compactPageInset,
                            AppSpacing.xl,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_error != null) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.error),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : widget.onCompleted,
                                  child: const Text('Continue to login'),
                                ),
                              ],
                              OnboardingIndicator(
                                index: _index,
                                count: _pages.length,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              AppButton(
                                label: _index == _pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                loadingLabel: 'Saving progress',
                                isLoading: _saving,
                                icon: Icons.arrow_forward_rounded,
                                onPressed: _changingPage || _saving
                                    ? null
                                    : () {
                                        if (_index == _pages.length - 1) {
                                          _complete();
                                        } else {
                                          _goToPage(_index + 1);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
