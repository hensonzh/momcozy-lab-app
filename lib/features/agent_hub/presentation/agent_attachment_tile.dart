import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

/// Shared metadata layout for pending images and documents.
class AgentAttachmentTile extends StatelessWidget {
  const AgentAttachmentTile({
    super.key,
    required this.name,
    required this.size,
    required this.preview,
    required this.removeButtonKey,
    required this.removeLabel,
    required this.onRemove,
  });

  final String name;
  final int size;
  final Widget preview;
  final Key removeButtonKey;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    if (largeText) return _buildLargeTextTile(context);

    return SizedBox(
      width: 94,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: const Color(0xFFFBF2F6),
                  child: SizedBox.square(dimension: 94, child: preview),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  key: removeButtonKey,
                  onPressed: onRemove,
                  tooltip: '$removeLabel $name',
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: MomHomeTokens.rose,
                  style: IconButton.styleFrom(
                    backgroundColor: MomHomeTokens.surface,
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFFE9E1E6)),
                    ),
                    minimumSize: const Size.square(32),
                    maximumSize: const Size.square(32),
                    fixedSize: const Size.square(32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MomHomeTokens.text(
              14,
              color: MomHomeTokens.secondary,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeTextTile(BuildContext context) {
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: MomHomeTokens.mint,
        child: SizedBox.square(dimension: 40, child: preview),
      ),
    );
    final metadata = AgentAttachmentMetadata(name: name, size: size);
    final remove = IconButton(
      key: removeButtonKey,
      onPressed: onRemove,
      tooltip: '$removeLabel $name',
      icon: const Icon(Icons.close_rounded, size: 20),
      color: MomHomeTokens.rose,
      disabledColor: MomHomeTokens.muted,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    return Container(
      width: 252,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MomHomeTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MomHomeTokens.border),
      ),
      child: Row(
        children: [
          thumbnail,
          const SizedBox(width: 10),
          Expanded(child: metadata),
          const SizedBox(width: 10),
          remove,
        ],
      ),
    );
  }
}

class AgentAttachmentMetadata extends StatelessWidget {
  const AgentAttachmentMetadata({
    super.key,
    required this.name,
    required this.size,
    this.sent = false,
  });
  final String name;
  final int size;
  final bool sent;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Tooltip(
        message: name,
        child: Text(
          name,
          maxLines: sent ? null : 2,
          overflow: sent ? null : TextOverflow.ellipsis,
          style: MomHomeTokens.text(14, weight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        agentAttachmentSize(size),
        style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
      ),
    ],
  );
}

String agentAttachmentSize(int bytes) {
  if (bytes <= 0) return 'Size unknown';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
