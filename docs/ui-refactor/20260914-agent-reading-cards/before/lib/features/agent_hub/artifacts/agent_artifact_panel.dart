import 'cards/agent_result_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/cards/agent_artifact_card_registry.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';

class AgentArtifactPanel extends StatelessWidget {
  const AgentArtifactPanel({
    super.key,
    required this.cards,
    this.onAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.formPresentationSession,
    this.autoPresentForms = false,
  });

  final List<AgentArtifactCardView> cards;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession? formPresentationSession;
  final bool autoPresentForms;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('agent-artifact-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final card in cards) ...[
          _buildCard(card),
          if (card != cards.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildCard(AgentArtifactCardView card) {
    if (card.isForm) return _buildForm(card);
    return _specializedArtifactCard(card: card, onAction: onAction) ??
        _AgentArtifactGenericCard(card: card, onAction: onAction);
  }

  Widget _buildForm(AgentArtifactCardView card) {
    final submissions = formSubmissionsListenable;
    if (submissions == null) {
      return AgentArtifactFormEntry(
        key: ValueKey('agent-artifact-form-entry-widget-${card.id}'),
        card: card,
        onAction: onAction,
        onSubmit: onFormSubmit,
        presentationSession: formPresentationSession,
        autoPresent: autoPresentForms,
      );
    }
    return ValueListenableBuilder<Map<String, AgentArtifactFormSubmission>>(
      valueListenable: submissions,
      builder: (context, values, child) {
        return AgentArtifactFormEntry(
          key: ValueKey('agent-artifact-form-entry-widget-${card.id}'),
          card: card,
          onAction: onAction,
          onSubmit: onFormSubmit,
          submission: values[card.id],
          presentationSession: formPresentationSession,
          autoPresent: autoPresentForms,
        );
      },
    );
  }
}

class _AgentArtifactGenericCard extends StatelessWidget {
  const _AgentArtifactGenericCard({required this.card, this.onAction});

  final AgentArtifactCardView card;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  Widget build(BuildContext context) {
    return AgentResultCard(
      key: ValueKey('agent-artifact-card-${card.id}'),
      title: card.title,
      status: card.statusLabel,
      icon: const Icon(
        Icons.dashboard_customize_outlined,
        size: 18,
        color: MomCozyColors.agentStrong,
      ),
      children: [
        if (card.content?.isNotEmpty == true)
          Text(card.content!, style: agentResultBodyStyle),
        for (final row in card.rows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(row, style: agentResultBodyStyle),
          ),
        if (card.actions.isNotEmpty) ...[
          if (card.content?.isNotEmpty == true || card.rows.isNotEmpty)
            const SizedBox(height: 12),
          for (var index = 0; index < card.actions.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            FilledButton.icon(
              key: ValueKey('agent-artifact-action-${card.id}-$index'),
              style: agentResultButtonStyle(),
              onPressed: onAction == null
                  ? null
                  : () => onAction!(card.actions[index]),
              icon: Icon(card.actions[index].icon, size: 18),
              label: Text(card.actions[index].label),
            ),
          ],
        ],
      ],
    );
  }
}

Widget? _specializedArtifactCard({
  required AgentArtifactCardView card,
  ValueChanged<AgentArtifactActionView>? onAction,
}) {
  final registeredCard = AgentArtifactCardRegistry.build(
    card: card,
    onAction: onAction,
  );
  if (registeredCard != null) return registeredCard;

  return switch (card.presentationKind) {
    AgentArtifactPresentationKind.unsupported => _AgentUnsupportedArtifactCard(
      card: card,
    ),
    _ => null,
  };
}

class _AgentUnsupportedArtifactCard extends StatelessWidget {
  const _AgentUnsupportedArtifactCard({required this.card});

  final AgentArtifactCardView card;

  @override
  Widget build(BuildContext context) {
    return AgentResultCard(
      key: ValueKey('agent-artifact-unsupported-${card.id}'),
      title: card.title,
      icon: const Icon(
        Icons.info_outline_rounded,
        size: 18,
        color: MomCozyColors.agentTextMuted,
      ),
      description: '此内容暂时无法显示。你可以继续对话。',
    );
  }
}
