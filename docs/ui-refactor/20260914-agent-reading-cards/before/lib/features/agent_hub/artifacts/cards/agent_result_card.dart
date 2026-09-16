import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

const agentResultBodyStyle = TextStyle(
  fontSize: 11,
  height: 1.45,
  letterSpacing: 0,
  color: MomCozyColors.agentTextMuted,
);

ButtonStyle agentResultButtonStyle() => FilledButton.styleFrom(
  backgroundColor: MomCozyColors.agentSoft,
  foregroundColor: MomCozyColors.agentStrong,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(
    fontFamily: MomCozyTypography.displayFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  ),
);

/// Compact result surface derived from the design's Agent recommendation card.
class AgentResultCard extends StatelessWidget {
  const AgentResultCard({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.status,
    this.children = const [],
  });
  final String title;
  final Widget icon;
  final String? description;
  final String? status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MomCozyColors.agentSuggestionSurface,
      border: Border.all(color: MomCozyColors.agentBorder),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0d3e626c),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: MomCozyColors.agentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: MomCozyTypography.displayFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.36,
                      letterSpacing: 0,
                      color: MomCozyColors.agentInk,
                    ),
                  ),
                  if (description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(description!, style: agentResultBodyStyle),
                  ],
                  if (status?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      status!,
                      style: agentResultBodyStyle.copyWith(
                        color: MomCozyColors.agentStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
      ],
    ),
  );
}
