import 'package:flutter/material.dart';

import '../design_system/mom_home_tokens.dart';
import '../design_system/mom_settings_theme.dart';
import 'mom_companion_widgets.dart';
export 'mom_card_background.dart';

class MomSettingsCard extends StatelessWidget {
  const MomSettingsCard({
    super.key,
    required this.children,
    this.gradient,
    this.color = MomHomeTokens.surface,
    this.border = true,
    this.padding = const EdgeInsets.all(MomHomeTokens.inset),
    this.spacing = MomHomeTokens.gap,
    this.borderInside = false,
    this.backgroundDecoration,
  });
  final List<Widget> children;
  final Gradient? gradient;
  final Color color;
  final bool border;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final bool borderInside;
  final MomCardDecoration? backgroundDecoration;

  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: gradient ?? LinearGradient(colors: [color, color]),
    border: border ? MomHomeTokens.border : null,
    borderInside: borderInside,
    backgroundDecoration: backgroundDecoration,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: children,
      ),
    ),
  );
}

/// Figma account and notification confirmations share this responsive layout.
class MomSettingsDialog extends StatelessWidget {
  const MomSettingsDialog({
    super.key,
    required this.title,
    required this.content,
    required this.primaryAction,
    required this.onCancel,
    this.cancelLabel = 'Cancel',
    this.closeLabel,
  });
  final String title;
  final Widget content;
  final Widget primaryAction;
  final VoidCallback onCancel;
  final String cancelLabel;

  /// Optional explicit dismiss action for flows that already expose one.
  final String? closeLabel;

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      title: closeLabel == null
          ? Text(title)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: closeLabel,
                  onPressed: onCancel,
                  color: MomHomeTokens.rose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
      content: content,
      actions: [
        SizedBox(
          width: double.maxFinite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              primaryAction,
              TextButton(onPressed: onCancel, child: Text(cancelLabel)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Figma form dialog: stable header and an independently scrolling body.
class MomSettingsFlowDialog extends StatelessWidget {
  const MomSettingsFlowDialog({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.child,
    this.maxHeight = 720,
    this.scrollController,
    this.showClose = true,
    this.closeIcon,
  });
  final String title, closeLabel;
  final VoidCallback? onClose;
  final Widget child;
  final double maxHeight;
  final ScrollController? scrollController;
  final bool showClose;
  final Widget? closeIcon;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height * .92;
    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: MomHomeTokens.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: maxHeight < viewportHeight ? maxHeight : viewportHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: MomHomeTokens.text(20, weight: FontWeight.w700),
                    ),
                  ),
                  if (showClose) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: closeLabel,
                      onPressed: onClose,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      padding: const EdgeInsets.all(12),
                      color: MomHomeTokens.rose,
                      style: closeIcon == null
                          ? null
                          : IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(44, 44),
                            ),
                      icon: closeIcon ?? const Icon(Icons.close, size: 20),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
