import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: MomHomeTokens.background,
      border: Border(bottom: BorderSide(color: MomHomeTokens.border)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: returnButtonKey,
                tooltip: '返回',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
                style: IconButton.styleFrom(
                  foregroundColor: MomHomeTokens.rose,
                  backgroundColor: MomHomeTokens.surface,
                  side: const BorderSide(color: MomHomeTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: title,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: title,
                  style: MomHomeTokens.text(16, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
