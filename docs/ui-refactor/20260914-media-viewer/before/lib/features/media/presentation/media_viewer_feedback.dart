import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';

class MediaViewerLoading extends StatelessWidget {
  const MediaViewerLoading({
    super.key,
    required this.label,
    this.darkBackground = true,
  });

  final String label;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('media-viewer-loading'),
      child: SingleChildScrollView(
        child: ProductLoadingView(
          label: label,
          foreground: darkBackground ? MomCozyColors.onMediaSecondary : null,
        ),
      ),
    );
  }
}

class MediaViewerLoadError extends StatelessWidget {
  const MediaViewerLoadError({
    super.key,
    required this.message,
    this.onRetry,
    this.darkBackground = true,
    this.icon = Icons.broken_image_outlined,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool darkBackground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final foreground = darkBackground
        ? MomCozyColors.onMediaSecondary
        : MomCozyColors.mutedForeground;
    return ColoredBox(
      color: darkBackground
          ? MomCozyColors.mediaBackground
          : MomCozyColors.background,
      child: Center(
        key: const ValueKey('media-viewer-load-error'),
        child: SingleChildScrollView(
          child: ProductEmptyView(
            title: message,
            icon: icon,
            foreground: foreground,
            action: onRetry == null
                ? null
                : IconButton(
                    key: const ValueKey('media-viewer-retry'),
                    tooltip: '重新加载',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    color: foreground,
                  ),
          ),
        ),
      ),
    );
  }
}
