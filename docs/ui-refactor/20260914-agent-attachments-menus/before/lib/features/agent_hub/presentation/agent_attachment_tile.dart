import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

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
  Widget build(BuildContext context) => Container(
    width: 218,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xf5fffdfc),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Color.lerp(Colors.white, MomCozyColors.agentBorder, .72)!,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x173e626c),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: const Color(0xfff2ebeb),
            child: SizedBox.square(dimension: 42, child: preview),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: AgentAttachmentMetadata(name: name, size: size),
        ),
        IconButton(
          key: removeButtonKey,
          onPressed: onRemove,
          tooltip: '$removeLabel $name',
          icon: const Icon(Icons.close_rounded, size: 19),
          color: const Color(0xff816b74),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            maximumSize: const Size.square(44),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: sent ? MomCozyColors.agentInk : const Color(0xff4b3941),
          ),
        ),
      ),
      SizedBox(height: sent ? 1 : 3),
      Text(
        agentAttachmentSize(size),
        style: TextStyle(
          fontSize: 9,
          height: 1.2,
          color: sent ? const Color(0xff8d7780) : const Color(0xff947f87),
        ),
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
