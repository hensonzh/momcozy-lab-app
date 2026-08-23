import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/ibclc_consult_store_scope.dart';

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
      accent: const Color(0xff8c4768),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfffffdfc),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffeadfe5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12412a34),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(icon, color: accent, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    card.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: const Color(0xff2f1f29),
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  MomCozyAssets.momcozyLogo,
                  width: 68,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 14),
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
    final completed =
        IbclcConsultStoreScope.maybeOf(context)?.isCompleted(data.consultId) ??
        false;
    final textTheme = Theme.of(context).textTheme;

    return KeyedSubtree(
      key: ValueKey('agent-artifact-ibclc-${widget.card.id}'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfffbfdfc),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffd6dde5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0d000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    size: 22,
                    color: Color(0xff177a89),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: const Color(0xff142726),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                key: ValueKey('agent-ibclc-consultant-${widget.card.id}'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffd6dde5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.consultantName,
                              style: textTheme.titleMedium?.copyWith(
                                color: const Color(0xff182b2a),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _IbclcConsultantTag(
                                  label: data.consultantCredentials,
                                  color: const Color(0xff1a6863),
                                  background: const Color(0xffe9f3f1),
                                ),
                                if (data.consultantExperience != null)
                                  _IbclcConsultantTag(
                                    label: data.consultantExperience!,
                                    color: const Color(0xff7a4260),
                                    background: const Color(0xfff4edf1),
                                  ),
                              ],
                            ),
                            if (data.consultantBio != null) ...[
                              const SizedBox(height: 7),
                              Text(
                                data.consultantBio!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xff60706e),
                                  fontSize: 13,
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
              if (!completed) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  key: ValueKey('agent-ibclc-consent-${widget.card.id}'),
                  decoration: BoxDecoration(
                    color: const Color(0xfff6fbfa),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffdbe7e4)),
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
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: Checkbox(
                                    key: ValueKey(
                                      'agent-ibclc-agreement-${widget.card.id}',
                                    ),
                                    value: _agreementAccepted,
                                    onChanged: (value) => setState(() {
                                      _agreementAccepted = value ?? false;
                                    }),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    activeColor: const Color(0xff177a89),
                                    side: const BorderSide(
                                      color: Color(0xffb9cbc8),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '我已阅读并同意《隐私政策》和《服务协议》',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: const Color(0xff586967),
                                    fontSize: 12,
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
                              color: const Color(0xff71807d),
                              fontSize: 11,
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
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: FilledButton(
                  key: ValueKey('agent-ibclc-open-${widget.card.id}'),
                  onPressed:
                      !completed &&
                          _agreementAccepted &&
                          widget.onAction != null
                      ? _openConsult
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff177a89),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xffd7dfdd),
                    disabledForegroundColor: const Color(0xff778683),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(completed ? '咨询结束' : data.chatLabel),
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
        value: '/ibclc-chat.html',
        routePath: '/ibclc-chat.html',
        routeExtra: IbclcConsultRouteDraft(
          consultId: widget.data.consultId,
          sourceArtifactId: widget.data.sourceArtifactId,
          consultantName: widget.data.consultantName,
          consultantCredentials: widget.data.consultantCredentials,
          consultantExperience: widget.data.consultantExperience ?? '',
          consultantBio: widget.data.consultantBio ?? '',
          chatLabel: widget.data.chatLabel,
          chatNote: widget.data.chatNote,
          reason: widget.data.reason ?? '',
          feedingContext: widget.data.feedingContext ?? '',
          urgency: widget.data.urgency,
          preferredLanguage: widget.data.preferredLanguage ?? '',
        ),
      ),
    );
  }
}

class _IbclcConsultantTag extends StatelessWidget {
  const _IbclcConsultantTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
