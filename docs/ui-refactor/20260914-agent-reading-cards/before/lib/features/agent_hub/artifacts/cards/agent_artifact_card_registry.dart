import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_line_icon.dart';
import 'agent_result_card.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

class AgentArtifactCardRegistry {
  const AgentArtifactCardRegistry._();

  static Widget? build({
    required AgentArtifactCardView card,
    ValueChanged<AgentArtifactActionView>? onAction,
  }) {
    return switch (card.presentationKind) {
      AgentArtifactPresentationKind.ibclcConsultCard =>
        card.specializedView is AgentIbclcConsultCardView
            ? _IbclcConsultCard(
                key: ValueKey('ibclc:${card.id}'),
                card: card,
                data: card.specializedView! as AgentIbclcConsultCardView,
                onAction: onAction,
              )
            : null,
      AgentArtifactPresentationKind.motionAssessmentCard =>
        card.specializedView is AgentMotionAssessmentCardView
            ? _MotionAssessmentCard(
                key: ValueKey('agent-motion-assessment-card-${card.id}'),
                data: card.specializedView! as AgentMotionAssessmentCardView,
                onAction: onAction,
              )
            : null,
      _ => null,
    };
  }
}

class _MotionAssessmentCard extends StatelessWidget {
  const _MotionAssessmentCard({super.key, required this.data, this.onAction});
  final AgentMotionAssessmentCardView data;
  final ValueChanged<AgentArtifactActionView>? onAction;
  @override
  Widget build(BuildContext context) => AgentResultCard(
    title: data.title,
    icon: const Icon(
      Icons.accessibility_new_rounded,
      size: 18,
      color: MomCozyColors.agentStrong,
    ),
    children: [
      FilledButton.icon(
        style: agentResultButtonStyle(),
        onPressed: onAction == null
            ? null
            : () {
                final uri = Uri.tryParse(data.routeLocation);
                onAction!(
                  AgentArtifactActionView(
                    label: data.startLabel,
                    icon: Icons.videocam_outlined,
                    kind: 'motion_assessment.open',
                    value: data.routeLocation,
                    routePath: uri?.path.isNotEmpty == true
                        ? uri!.path
                        : '/motion-assessment',
                  ),
                );
              },
        icon: const Icon(Icons.videocam_outlined, size: 18),
        label: Text(data.startLabel),
      ),
    ],
  );
}

class _IbclcConsultCard extends StatefulWidget {
  const _IbclcConsultCard({
    super.key,
    required this.card,
    required this.data,
    this.onAction,
  });

  final AgentArtifactCardView card;
  final AgentIbclcConsultCardView data;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  State<_IbclcConsultCard> createState() => _IbclcConsultCardState();
}

class _IbclcConsultCardState extends State<_IbclcConsultCard> {
  bool _agreementAccepted = false;

  @override
  void didUpdateWidget(covariant _IbclcConsultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.consultId != widget.data.consultId) {
      _agreementAccepted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // Completion is owned by the service/appointment backend. The Agent Hub
    // only hands the user into that flow and never persists a local consult.
    return AgentResultCard(
      key: ValueKey('agent-artifact-ibclc-${widget.card.id}'),
      title: data.title,
      description: data.reason,
      icon: const MomCozyLineIcon(
        MomCozyLineGlyph.users,
        size: 18,
        color: MomCozyColors.agentStrong,
      ),
      children: [
        Padding(
          key: ValueKey('agent-ibclc-consultant-${widget.card.id}'),
          padding: const EdgeInsets.only(left: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.consultantName,
                style: agentResultBodyStyle.copyWith(
                  color: MomCozyColors.agentInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                [
                  data.consultantCredentials,
                  if (data.consultantExperience?.isNotEmpty == true)
                    data.consultantExperience!,
                ].join(' · '),
                style: agentResultBodyStyle,
              ),
              if (data.consultantBio?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(data.consultantBio!, style: agentResultBodyStyle),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Column(
          key: ValueKey('agent-ibclc-consent-${widget.card.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  setState(() => _agreementAccepted = !_agreementAccepted),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: Checkbox(
                      key: ValueKey('agent-ibclc-agreement-${widget.card.id}'),
                      value: _agreementAccepted,
                      activeColor: MomCozyColors.agentStrong,
                      side: const BorderSide(
                        color: MomCozyColors.agentTextMuted,
                      ),
                      onChanged: (value) =>
                          setState(() => _agreementAccepted = value ?? false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '我已阅读并同意《隐私政策》和《服务协议》',
                      style: agentResultBodyStyle.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (data.chatNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(data.chatNote, style: agentResultBodyStyle),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: ValueKey('agent-ibclc-open-${widget.card.id}'),
          style: agentResultButtonStyle(),
          onPressed: _agreementAccepted && widget.onAction != null
              ? _openConsult
              : null,
          child: Text(data.chatLabel),
        ),
      ],
    );
  }

  void _openConsult() {
    widget.onAction?.call(
      AgentArtifactActionView(
        label: '咨询 IBCLC',
        icon: Icons.chat_bubble_outline_rounded,
        kind: 'artifact',
        value: '/services',
        routePath: '/services',
      ),
    );
  }
}
