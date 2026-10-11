import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 42, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: light
          ? AppTheme.colors(context).surface
          : AppTheme.colors(context).accent,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(
      Icons.alt_route_rounded,
      color: light
          ? AppTheme.colors(context).accent
          : AppTheme.colors(context).onAccent,
      size: size * .64,
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topRight,
        radius: 1.1,
        colors: [
          AppTheme.colors(context).tint,
          AppTheme.colors(context).canvas,
        ],
        stops: [0, .65],
      ),
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(padding: padding, child: child),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.warning = false,
  });
  final String text;
  final IconData icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning
          ? AppTheme.colors(context).warningSurface
          : AppTheme.colors(context).surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: warning
              ? AppTheme.colors(context).warning
              : AppTheme.colors(context).accent,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.colors(context).ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, this.text = 'ON THE GO', this.dark = false});
  final String text;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.colors(context).tint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: .8,
        fontWeight: FontWeight.w800,
        color: AppTheme.colors(context).accent,
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 26, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 38, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppTheme.colors(context).tint,
          child: Icon(icon, size: 34, color: AppTheme.colors(context).accent),
        ),
        SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.colors(context).muted,
          ),
        ),
        if (action != null)
          Padding(padding: EdgeInsets.only(top: 20), child: action),
      ],
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Getting things ready…'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(message),
      ],
    ),
  );
}
