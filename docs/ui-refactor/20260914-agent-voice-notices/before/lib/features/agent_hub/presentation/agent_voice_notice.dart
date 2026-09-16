import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

/// Recovery notice from the design's neutral Agent toast.
class AgentVoiceNotice extends StatelessWidget {
  const AgentVoiceNotice({super.key, required this.onDismiss, this.onReplay});
  final VoidCallback onDismiss;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
    decoration: BoxDecoration(
      color: const Color(0xfaf5f9f9),
      border: Border.all(color: MomCozyColors.agentBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const message = Text(
          '语音暂时无法播放，你可以继续阅读回复。',
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: MomCozyColors.agentStrong,
          ),
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onReplay,
              style: TextButton.styleFrom(
                foregroundColor: MomCozyColors.agentStrong,
                minimumSize: const Size(44, 44),
                textStyle: const TextStyle(
                  fontFamily: MomCozyTypography.fontFamily,
                  fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('播放回复'),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: '关闭语音提示',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: MomCozyColors.agentStrong,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        );
        final stacked =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(13) > 17;
        return Semantics(
          liveRegion: true,
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    message,
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    const Expanded(child: message),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
        );
      },
    ),
  );
}
