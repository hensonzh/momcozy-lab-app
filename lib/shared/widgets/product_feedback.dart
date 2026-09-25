import 'package:flutter/material.dart';
import '../../domain/shared/product_failure.dart';
import '../design_system/momcozy_design_system.dart';
import '../design_system/momcozy_text_roles.dart';
import '../design_system/mom_home_tokens.dart';
import 'mom_settings_widgets.dart';

class ProductErrorView extends StatelessWidget {
  const ProductErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.preserveDraft = false,
    this.useMomStyle = false,
    this.compactMomStyle = false,
  });
  final ProductFailure failure;
  final VoidCallback? onRetry;
  final bool preserveDraft;
  final bool useMomStyle;
  final bool compactMomStyle;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure.kind) {
      ProductFailureKind.offline => 'You\'re offline. Connect and try again.',
      ProductFailureKind.unauthenticated =>
        'Your session has expired. Sign in again to continue.',
      ProductFailureKind.forbidden => 'This account does not have access.',
      ProductFailureKind.conflict =>
        'This record was updated elsewhere. Reload to review the latest version.',
      ProductFailureKind.invalid => 'Check your information and try again.',
      ProductFailureKind.unavailable =>
        'Could not load right now. Please try again later.',
    };
    if (useMomStyle) {
      return Semantics(
        liveRegion: true,
        child: MomSettingsCard(
          color: MomCozyColors.amberSoft,
          padding: compactMomStyle
              ? const EdgeInsets.fromLTRB(16, 16, 16, 15)
              : const EdgeInsets.all(MomHomeTokens.inset),
          spacing: compactMomStyle ? 4 : MomHomeTokens.gap,
          children: [
            Text(message, style: MomHomeTokens.text(13, height: 1.55)),
            if (preserveDraft)
              Text(
                'Your entries are still here.',
                style: MomHomeTokens.text(13),
              ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  failure.kind == ProductFailureKind.conflict
                      ? 'Reload'
                      : 'Try again',
                ),
              ),
          ],
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MomCozyColors.amberSoft,
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: MomCozyTextRoles.paragraphOf(
                context,
              ).copyWith(color: MomCozyColors.foreground),
            ),
            if (preserveDraft)
              Text(
                'Your entries are still here.',
                style: MomCozyTextRoles.paragraphOf(context),
              ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  failure.kind == ProductFailureKind.conflict
                      ? 'Reload'
                      : 'Try again',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProductEmptyView extends StatelessWidget {
  const ProductEmptyView({
    super.key,
    required this.title,
    this.description,
    this.action,
    this.icon,
    this.foreground,
    this.textAlign = TextAlign.center,
  });
  final String title;
  final String? description;
  final Widget? action;
  final IconData? icon;
  final Color? foreground;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlign == TextAlign.start
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: MomCozyIconSizes.feature,
            color: foreground ?? MomCozyColors.iconSecondary,
          ),
          const SizedBox(height: MomCozySpacing.content),
        ],
        Text(
          title,
          textAlign: textAlign,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
            fontSize: MomCozyTypography.titleSize,
          ),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              description!,
              textAlign: textAlign,
              style: MomCozyTextRoles.paragraphOf(
                context,
              ).copyWith(color: foreground),
            ),
          ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action!),
      ],
    ),
  );
}

class ProductLoadingView extends StatelessWidget {
  const ProductLoadingView({super.key, this.label, this.foreground});
  final String? label;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? 'Loading',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(MomCozySpacing.section),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: foreground),
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MomCozySpacing.content),
                    child: Text(
                      label!,
                      textAlign: TextAlign.center,
                      style: MomCozyTypography.secondaryText
                          .merge(MomCozyTextRoles.paragraphOf(context))
                          .copyWith(color: foreground),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A non-interactive skeleton with no fake content or perpetual animation.
class ProductSkeleton extends StatelessWidget {
  const ProductSkeleton({super.key, this.lines = 3, this.label = 'Loading'});
  final int lines;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: MomCozySpacing.content),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: index == lines - 1 ? .65 : 1,
                child: Container(
                  height: MomCozySpacing.page,
                  decoration: BoxDecoration(
                    color: MomCozyColors.secondary,
                    borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
