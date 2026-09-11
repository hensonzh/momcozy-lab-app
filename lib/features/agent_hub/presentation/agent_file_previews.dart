import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

class AgentComposerFileAttachment extends StatelessWidget {
  const AgentComposerFileAttachment({
    super.key,
    required this.file,
    required this.removeButtonKey,
    required this.onRemove,
  });

  final AgentStreamFileInput file;
  final Key removeButtonKey;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 70,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: MomCozyColors.card,
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: MomCozyColors.muted,
              borderRadius: BorderRadius.circular(MomCozyRadii.thumbnail),
            ),
            child: const SizedBox.square(
              dimension: 42,
              child: Icon(Icons.picture_as_pdf_outlined, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fileSizeLabel(file.size),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: removeButtonKey,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: '移除文件',
            style: IconButton.styleFrom(
              fixedSize: const Size.square(28),
              minimumSize: const Size.square(28),
              maximumSize: const Size.square(28),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class AgentSentFiles extends StatelessWidget {
  const AgentSentFiles({super.key, required this.files});

  final List<AgentStreamFileInput> files;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < files.length; index++) ...[
          Container(
            key: ValueKey('agent-sent-file-$index'),
            constraints: const BoxConstraints(minWidth: 190),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: MomCozyColors.card.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(MomCozyRadii.control),
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.72),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        files[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _fileSizeLabel(files[index].size),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != files.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

String _fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}
