import 'package:flutter/material.dart';
import '../design_system/momcozy_design_system.dart';

/// Shared width/insets only. The caller retains its scroll controller, refresh
/// behavior and state; this container does not introduce another scroll view.
class MomCozyPageBody extends StatelessWidget {
  const MomCozyPageBody({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.maxWidth = MomCozyLayout.maxAppWidth,
    this.safeArea = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return safeArea ? SafeArea(child: content) : content;
  }
}

class MomCozyPageHeader extends StatelessWidget {
  const MomCozyPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: MomCozySpacing.content,
    runSpacing: MomCozySpacing.compact,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: MomCozySpacing.xs),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: MomCozyTypography.secondarySize,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
      ?trailing,
    ],
  );
}

class MomCozySectionHeading extends StatelessWidget {
  const MomCozySectionHeading({
    super.key,
    required this.title,
    this.icon,
    this.action,
  });
  final String title;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      MomCozySpacing.xs,
      0,
      MomCozySpacing.xs,
      MomCozySpacing.headingGap,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final heading = Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: MomCozyIconSizes.standard,
                color: MomCozyColors.iconPrimary,
              ),
              const SizedBox(width: MomCozySpacing.compact),
            ],
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (!stacked && action != null) action!,
          ],
        );
        return stacked && action != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              )
            : heading;
      },
    ),
  );
}

class MomCozySurface extends StatelessWidget {
  const MomCozySurface({
    super.key,
    required this.child,
    this.padding = MomCozyInsets.card,
    this.color,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    clipBehavior: Clip.antiAlias,
    child: onTap == null
        ? Padding(padding: padding, child: child)
        : InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
  );
}

class MomCozyBadge extends StatelessWidget {
  const MomCozyBadge(
    this.label, {
    super.key,
    this.color = MomCozyColors.mutedForeground,
    this.background = MomCozyColors.muted,
  });
  final String label;
  final Color color, background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: MomCozySpacing.compact,
      vertical: MomCozySpacing.xs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(MomCozyRadii.badge),
    ),
    child: Text(label, style: MomCozyTypography.label.copyWith(color: color)),
  );
}

/// Only presents the caller's loading state; callbacks and async decisions stay
/// with the feature controller.
class MomCozyPrimaryButton extends StatelessWidget {
  const MomCozyPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loading = false,
    this.destructive = false,
    this.icon,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool loading, destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, MomCozyLayout.primaryButtonHeight),
      backgroundColor: destructive ? MomCozyColors.danger : null,
    ),
    child: loading || icon != null
        ? Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MomCozySpacing.compact,
            runSpacing: MomCozySpacing.xs,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: MomCozyIconSizes.medium,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: MomCozyIconSizes.medium),
              child,
            ],
          )
        : child,
  );
}
