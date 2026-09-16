import 'package:flutter/material.dart';
import 'agent_attachment_tile.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_line_icon.dart';
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
    return AgentAttachmentTile(
      name: file.name,
      size: file.size,
      removeButtonKey: removeButtonKey,
      removeLabel: '移除文件',
      onRemove: onRemove,
      preview: const Center(
        child: MomCozyLineIcon(
          MomCozyLineGlyph.file,
          size: 21,
          color: Color(0xff765b66),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0x1a6d4e5b)),
            ),
            child: Row(
              children: [
                const MomCozyLineIcon(
                  MomCozyLineGlyph.file,
                  size: 20,
                  color: Color(0xff765b66),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AgentAttachmentMetadata(
                    name: files[index].name,
                    size: files[index].size,
                    sent: true,
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
