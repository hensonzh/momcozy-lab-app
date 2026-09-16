import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../application/baby_home_controller.dart';

class BabySavedFeedbackView extends StatelessWidget {
  const BabySavedFeedbackView({
    super.key,
    required this.feedback,
    required this.onUndo,
    required this.onDismiss,
    required this.onHistory,
  });
  final BabySavedFeedback feedback;
  final VoidCallback onUndo, onDismiss, onHistory;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: feedback.failure == null
            ? MomHomeTokens.mint
            : const Color(0xfff6eddc),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Icon(
              feedback.failure == null
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 18,
              color: feedback.failure == null
                  ? MomHomeTokens.teal
                  : MomHomeTokens.secondary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(feedback.message, style: MomHomeTokens.text(14)),
                ),
                if (!feedback.undone &&
                    feedback.allowUndo &&
                    feedback.retryable)
                  TextButton(
                    onPressed: feedback.canUndo ? onUndo : null,
                    child: Text(feedback.failure == null ? '撤销' : '重试确认撤销'),
                  ),
                if (feedback.failure != null && !feedback.retryable)
                  TextButton(onPressed: onHistory, child: const Text('核对全部记录')),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭保存提示',
            onPressed: feedback.busy ? null : onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    ),
  );
}
