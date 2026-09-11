import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_components.dart';
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
                card: card,
                data: card.specializedView! as AgentMotionAssessmentCardView,
                onAction: onAction,
              )
            : null,
      _ => null,
    };
  }
}

class _MotionAssessmentCard extends StatelessWidget {
  const _MotionAssessmentCard({
    super.key,
    required this.card,
    required this.data,
    this.onAction,
  });

  final AgentArtifactCardView card;
  final AgentMotionAssessmentCardView data;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  Widget build(BuildContext context) {
    return _ArtifactCardSurface(
      card: card,
      icon: Icons.accessibility_new_rounded,
      accent: MomCozyColors.primary,
      children: [
        FilledButton.icon(
          onPressed: () {
            final uri = Uri.tryParse(data.routeLocation);
            onAction?.call(
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
          icon: const Icon(Icons.videocam_outlined),
          label: Text(data.startLabel),
        ),
      ],
    );
  }
}

class _ArtifactCardSurface extends StatelessWidget {
  const _ArtifactCardSurface({
    required this.card,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final AgentArtifactCardView card;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MomCozySurface(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(MomCozySpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(icon, color: accent, size: 22),
                  ),
                ),
                const SizedBox(width: MomCozySpacing.content),
                Expanded(
                  child: Text(
                    card.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: MomCozySpacing.compact),
                Image.asset(
                  MomCozyAssets.momcozyLogo,
                  width: 68,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: MomCozySpacing.headingGap),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
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
    final textTheme = Theme.of(context).textTheme;

    return KeyedSubtree(
      key: ValueKey('agent-artifact-ibclc-${widget.card.id}'),
      child: MomCozySurface(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: MomCozyInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    size: 22,
                    color: MomCozyColors.primary,
                  ),
                  const SizedBox(width: MomCozySpacing.compact),
                  Expanded(
                    child: Text(
                      data.title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: MomCozyColors.foreground,
                        fontSize: MomCozyTypography.sectionSize,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MomCozySpacing.headingGap),
              DecoratedBox(
                key: ValueKey('agent-ibclc-consultant-${widget.card.id}'),
                decoration: BoxDecoration(
                  color: MomCozyColors.card,
                  borderRadius: BorderRadius.circular(MomCozyRadii.control),
                  border: Border.all(color: MomCozyColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(MomCozySpacing.content),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ClipOval(
                          child: Image.asset(
                            MomCozyAssets.ibclcConsultantAvatar,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            semanticLabel: data.consultantName,
                          ),
                        ),
                      ),
                      const SizedBox(width: MomCozySpacing.content),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.consultantName,
                              style: textTheme.titleMedium?.copyWith(
                                color: MomCozyColors.foreground,
                                fontSize: MomCozyTypography.titleSize,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                MomCozyBadge(
                                  data.consultantCredentials,
                                  color: MomCozyColors.care,
                                  background: MomCozyColors.careSoft,
                                ),
                                if (data.consultantExperience != null)
                                  MomCozyBadge(
                                    data.consultantExperience!,
                                    color: MomCozyColors.primaryDark,
                                    background: MomCozyColors.roseSoft,
                                  ),
                              ],
                            ),
                            if (data.consultantBio != null) ...[
                              const SizedBox(height: 7),
                              Text(
                                data.consultantBio!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: MomCozyColors.mutedForeground,
                                  fontSize: MomCozyTypography.secondarySize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...[
                const SizedBox(height: MomCozySpacing.headingGap),
                DecoratedBox(
                  key: ValueKey('agent-ibclc-consent-${widget.card.id}'),
                  decoration: BoxDecoration(
                    color: MomCozyColors.careSoft,
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                    border: Border.all(color: MomCozyColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            _agreementAccepted = !_agreementAccepted;
                          }),
                          borderRadius: BorderRadius.circular(
                            MomCozyRadii.badge,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: SizedBox.square(
                                  dimension: MomCozyTapTargets.minimum,
                                  child: Checkbox(
                                    key: ValueKey(
                                      'agent-ibclc-agreement-${widget.card.id}',
                                    ),
                                    value: _agreementAccepted,
                                    onChanged: (value) => setState(() {
                                      _agreementAccepted = value ?? false;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: MomCozySpacing.compact),
                              Expanded(
                                child: Text(
                                  '我已阅读并同意《隐私政策》和《服务协议》',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: MomCozyColors.mutedForeground,
                                    fontSize: MomCozyTypography.captionSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 6),
                          child: Text(
                            data.chatNote,
                            style: textTheme.labelSmall?.copyWith(
                              color: MomCozyColors.mutedForeground,
                              fontSize: MomCozyTypography.labelSize,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: MomCozySpacing.headingGap),
              SizedBox(
                child: FilledButton(
                  key: ValueKey('agent-ibclc-open-${widget.card.id}'),
                  onPressed: _agreementAccepted && widget.onAction != null
                      ? _openConsult
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      0,
                      MomCozyLayout.primaryButtonHeight,
                    ),
                  ),
                  child: Text(data.chatLabel),
                ),
              ),
            ],
          ),
        ),
      ),
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
