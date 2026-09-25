import 'package:flutter/material.dart';

import '../design_system/mom_home_tokens.dart';
import 'momcozy_line_icon.dart';

/// Figma MomCozy/SettingsRow (122:2); grows with text instead of clipping.
class MomSettingsRow extends StatelessWidget {
  const MomSettingsRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.unreadCount = 0,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(MomHomeTokens.inset),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: Text(
                    title,
                    style: MomHomeTokens.text(16, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: Text(
                    subtitle,
                    style: MomHomeTokens.text(
                      12,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: MomHomeTokens.gap),
            Semantics(
              label: '$unreadCount unread notifications',
              excludeSemantics: true,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: MomHomeTokens.text(
                  12,
                  weight: FontWeight.w700,
                  color: MomHomeTokens.rose,
                ),
              ),
            ),
          ],
          const SizedBox(width: MomHomeTokens.gap),
          const MomCozyLineIcon(
            MomCozyLineGlyph.chevronRight,
            size: 16,
            color: MomHomeTokens.secondary,
          ),
        ],
      ),
    ),
  );
}
