import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

/// Playback recovery stays separate from the reply and never hides its text.
class AgentVoiceNotice extends StatelessWidget {
  const AgentVoiceNotice({super.key, required this.onDismiss, this.onReplay});
  final VoidCallback onDismiss;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MomHomeTokens.surface,
        border: Border.all(color: MomHomeTokens.border),
        borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('语音暂时无法播放，你可以继续阅读回复。', style: MomHomeTokens.text(13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onReplay,
                  style: TextButton.styleFrom(
                    foregroundColor: MomHomeTokens.teal,
                    backgroundColor: MomHomeTokens.mint,
                    disabledForegroundColor: MomHomeTokens.secondary,
                    disabledBackgroundColor: MomHomeTokens.neutralSurface,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.all(12),
                    textStyle: MomHomeTokens.text(13, weight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('播放回复'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  onPressed: onDismiss,
                  tooltip: '关闭语音提示',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: MomHomeTokens.rose,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
