import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_settings_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_settings_widgets.dart';

class MediaViewerLoading extends StatelessWidget {
  const MediaViewerLoading({
    super.key,
    required this.label,
    this.darkBackground = true,
  });

  final String label;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) => _MediaFeedbackSurface(
    key: const ValueKey('media-viewer-loading'),
    darkBackground: darkBackground,
    children: [
      Text(label, style: MomHomeTokens.text(16, weight: FontWeight.w600)),
      const LinearProgressIndicator(
        color: MomHomeTokens.rose,
        backgroundColor: MomHomeTokens.mint,
        minHeight: 4,
      ),
    ],
  );
}

class MediaViewerLoadError extends StatelessWidget {
  const MediaViewerLoadError({
    super.key,
    required this.message,
    this.description,
    this.onRetry,
    this.darkBackground = true,
    this.icon = Icons.broken_image_outlined,
    this.retryButtonKey = const ValueKey('media-viewer-retry'),
    this.retryLabel = '重新加载',
  });

  final String message;
  final String? description;
  final VoidCallback? onRetry;
  final bool darkBackground;
  final IconData icon;
  final Key retryButtonKey;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => _MediaFeedbackSurface(
    key: const ValueKey('media-viewer-load-error'),
    darkBackground: darkBackground,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MomHomeTokens.mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: MomHomeTokens.teal, size: 22),
        ),
      ),
      Text(message, style: MomHomeTokens.text(18, weight: FontWeight.w600)),
      if (description case final text?)
        Text(
          text,
          style: MomHomeTokens.text(14, color: MomHomeTokens.secondary),
        ),
      if (onRetry != null)
        FilledButton(
          key: retryButtonKey,
          onPressed: onRetry,
          child: Text(retryLabel),
        ),
    ],
  );
}

class _MediaFeedbackSurface extends StatelessWidget {
  const _MediaFeedbackSurface({
    super.key,
    required this.darkBackground,
    required this.children,
  });

  final bool darkBackground;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: darkBackground
        ? MomCozyColors.mediaBackground
        : MomHomeTokens.background,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Theme(
            data: momSettingsTheme(Theme.of(context)),
            child: MomSettingsCard(children: children),
          ),
        ),
      ),
    ),
  );
}
