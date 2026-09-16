import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_settings_widgets.dart';

const agentResultBodyStyle = TextStyle(
  fontFamily: 'NotoSansSCHome',
  fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
  fontSize: 14,
  height: 1.4,
  letterSpacing: 0,
  color: MomHomeTokens.secondary,
);

ButtonStyle agentResultButtonStyle({bool primary = false}) =>
    FilledButton.styleFrom(
      backgroundColor: primary ? MomHomeTokens.rose : MomHomeTokens.mint,
      foregroundColor: primary ? MomHomeTokens.surface : MomHomeTokens.teal,
      disabledBackgroundColor: MomHomeTokens.neutralSurface,
      disabledForegroundColor: MomHomeTokens.secondary,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: MomHomeTokens.text(13, weight: FontWeight.w600),
    );

/// Shared hierarchy for an Agent result, its context and available actions.
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
  Widget build(BuildContext context) => MomSettingsCard(
    backgroundDecoration: MomCardDecoration.resource,
    children: [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MomHomeTokens.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
      if (description?.trim().isNotEmpty == true)
        Text(description!, style: agentResultBodyStyle),
      if (status?.trim().isNotEmpty == true)
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MomHomeTokens.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status!,
              style: MomHomeTokens.text(
                13,
                weight: FontWeight.w600,
                color: MomHomeTokens.teal,
              ),
            ),
          ),
        ),
      if (children.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
    ],
  );
}
