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
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: const Color(0xFFF5E7ED),
                  child: SizedBox.square(dimension: 64, child: preview),
                ),
              ),
              Positioned(
                top: -1,
                right: -1,
                child: IconButton(
                  key: removeButtonKey,
                  onPressed: onRemove,
                  tooltip: '$removeLabel $name',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: MomHomeTokens.rose,
                  style: IconButton.styleFrom(
                    backgroundColor: MomHomeTokens.surface,
                    minimumSize: const Size.square(24),
                    maximumSize: const Size.square(24),
                    fixedSize: const Size.square(24),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
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
  if (bytes <= 0) return '大小未知';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
