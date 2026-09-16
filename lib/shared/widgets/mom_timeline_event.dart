import 'package:flutter/material.dart';
import '../design_system/mom_home_tokens.dart';
import 'mom_settings_widgets.dart';

/// A dated service record. Callers retain the meaning and availability of actions.
class MomTimelineEvent extends StatelessWidget {
  const MomTimelineEvent({
    super.key,
    required this.dateLabel,
    required this.title,
    required this.description,
    this.author,
    this.actionLabel,
    this.onAction,
    this.latest = false,
  });
  final String dateLabel, title, description;
  final String? author, actionLabel;
  final VoidCallback? onAction;
  final bool latest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MomHomeTokens.gap),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 10,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  const Positioned(
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: MomHomeTokens.border,
                      child: SizedBox(width: 1),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: latest ? MomHomeTokens.rose : MomHomeTokens.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MomSettingsCard(
              color: latest ? MomHomeTokens.mint : MomHomeTokens.surface,
              children: [
                Text(
                  dateLabel,
                  style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
                ),
                Text(
                  title,
                  style: MomHomeTokens.text(16, weight: FontWeight.w700),
                ),
                if (author != null)
                  Text(
                    author!,
                    style: MomHomeTokens.text(
                      12,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                Text(
                  description,
                  style: MomHomeTokens.text(
                    13,
                    height: 1.55,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                if (onAction != null)
                  TextButton(
                    onPressed: onAction,
                    child: Row(
                      children: [
                        Expanded(child: Text(actionLabel!)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
