import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    required this.storageId,
    required this.child,
    this.controller,
    super.key,
  });

  final String storageId;
  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.lg
        : AppSpacing.compactPageInset;

    return SingleChildScrollView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      key: PageStorageKey<String>(storageId),
      primary: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              inset,
              AppSpacing.xl,
              inset,
              AppSpacing.xxl,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
