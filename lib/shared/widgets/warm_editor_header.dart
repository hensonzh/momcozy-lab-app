import 'package:flutter/material.dart';
import '../design_system/momcozy_design_system.dart';

/// Shared header for the warm record and profile dialogs in the design reference.
class WarmEditorHeader extends StatelessWidget {
  const WarmEditorHeader({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    this.maxTitleLines = 2,
  });
  final String title, closeLabel;
  final VoidCallback? onClose;
  final int maxTitleLines;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MomCozyColors.warmEditorHeader,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: maxTitleLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                height: 1.4,
                color: MomCozyColors.warmEditorBright,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: closeLabel,
            onPressed: onClose,
            style: IconButton.styleFrom(
              foregroundColor: MomCozyColors.warmEditorBright,
              shape: const CircleBorder(),
              backgroundColor: Colors.white.withValues(alpha: .04),
              side: const BorderSide(color: Color(0x669d8877)),
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
