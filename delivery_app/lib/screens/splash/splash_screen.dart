import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/onboarding_store.dart';
import '../../widgets/app_brand.dart';
import '../../widgets/journey_illustration.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.store,
    required this.onFinished,
    super.key,
  });

  final OnboardingStore store;
  final ValueChanged<bool> onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _intro = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_intro);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
    _start();
  }

  Future<bool> _readPreference() async {
    try {
      return await widget.store.isCompleted().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      // A missing/unreadable preference is safe to treat as a first launch.
      return false;
    }
  }

  Future<void> _start() async {
    final preference = _readPreference();
    try {
      await _controller.forward().orCancel;
      final completed = await preference;
      if (mounted) widget.onFinished(completed);
    } on TickerCanceled {
      // The user may close the app before the introduction finishes.
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.forest,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.forest,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: FadeTransition(
                          opacity: _intro,
                          child: SlideTransition(
                            position: _slide,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppBrand(onDark: true),
                                const SizedBox(height: AppSpacing.xxxl),
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) =>
                                      JourneyIllustration(
                                        scene: JourneyScene.shopRoute,
                                        progress: _controller.value,
                                        onDark: true,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                Text(
                                  AppStrings.tagline,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
