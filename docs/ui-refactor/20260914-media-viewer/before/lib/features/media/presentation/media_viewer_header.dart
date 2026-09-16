import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

class MediaViewerHeader extends StatelessWidget {
  const MediaViewerHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.returnButtonKey = const ValueKey('media-return-button'),
  });

  final String title;
  final VoidCallback onBack;
  final Key returnButtonKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MomCozyColors.background,
        border: Border(bottom: BorderSide(color: MomCozyColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MomCozyLayout.headerHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MomCozySpacing.pageGutter,
              vertical: MomCozySpacing.xs,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: MomCozyTapTargets.minimum,
                  child: IconButton(
                    key: returnButtonKey,
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: MomCozyIconSizes.standard,
                    ),
                    color: MomCozyColors.foreground,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: MomCozySpacing.content),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    semanticsLabel: title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      height: 1.4,
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w700,
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
