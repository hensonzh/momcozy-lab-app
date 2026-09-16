import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
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
          color: MomHomeTokens.teal,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: MomHomeTokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MomHomeTokens.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MomHomeTokens.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: MomCozyLineIcon(
                      MomCozyLineGlyph.file,
                      size: 20,
                      color: MomHomeTokens.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
          if (index != files.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
