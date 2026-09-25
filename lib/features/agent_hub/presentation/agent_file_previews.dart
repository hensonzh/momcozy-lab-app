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
      removeLabel: 'Remove file',
      onRemove: onRemove,
      preview: const Center(
        child: MomCozyLineIcon(
          MomCozyLineGlyph.file,
          size: 21,
          color: MomHomeTokens.rose,
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
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < files.length; index++) ...[
          Container(
            key: ValueKey('agent-sent-file-$index'),
            width: 244,
            height: largeText ? 96 : 56,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MomHomeTokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MomHomeTokens.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: MomCozyLineIcon(
                      MomCozyLineGlyph.file,
                      size: 20,
                      color: MomHomeTokens.rose,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: files[index].name,
                        child: Text(
                          files[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MomHomeTokens.text(
                            14,
                            height: 18 / 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${_fileType(files[index].name)} · ${agentAttachmentSize(files[index].size)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MomHomeTokens.text(
                          11,
                          height: 14 / 11,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                    ],
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

String _fileType(String name) {
  final separator = name.lastIndexOf('.');
  final extension = separator >= 0 ? name.substring(separator + 1).trim() : '';
  return extension.isEmpty ? 'FILE' : extension.toUpperCase();
}
