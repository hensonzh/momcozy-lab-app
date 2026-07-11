import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/cards/agent_artifact_card_registry.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form.dart';

class AgentArtifactPanel extends StatelessWidget {
  const AgentArtifactPanel({
    super.key,
    required this.cards,
    this.onAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
  });

  final List<AgentArtifactCardView> cards;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('agent-artifact-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final card in cards) ...[
          if (card.isForm)
            _buildForm(card)
          else
            _specializedArtifactCard(card: card, onAction: onAction) ??
                _AgentArtifactGenericCard(card: card, onAction: onAction),
          if (card != cards.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildForm(AgentArtifactCardView card) {
    final submissions = formSubmissionsListenable;
    if (submissions == null) {
      return AgentArtifactForm(
        card: card,
        onAction: onAction,
        onSubmit: onFormSubmit,
      );
    }
    return ValueListenableBuilder<Map<String, AgentArtifactFormSubmission>>(
      valueListenable: submissions,
      builder: (context, values, child) {
        return AgentArtifactForm(
          card: card,
          onAction: onAction,
          onSubmit: onFormSubmit,
          submission: values[card.id],
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      key: ValueKey('agent-artifact-card-${card.id}'),
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.74)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.dashboard_customize_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.title,
                    style: textTheme.titleSmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (card.statusLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    card.statusLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            if (card.content != null) ...[
              const SizedBox(height: 8),
              Text(
                card.content!,
                style: textTheme.bodySmall?.copyWith(
                  height: 1.35,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ],
            for (final row in card.rows) ...[
              const SizedBox(height: 8),
              Text(
                row,
                style: textTheme.bodySmall?.copyWith(
                  height: 1.35,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ],
            if (card.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < card.actions.length; index++)
                    OutlinedButton.icon(
                      key: ValueKey('agent-artifact-action-${card.id}-$index'),
                      onPressed: () => onAction?.call(card.actions[index]),
                      icon: Icon(card.actions[index].icon),
                      label: Text(card.actions[index].label),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
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
    AgentArtifactPresentationKind.milkAnalysisCard ||
    AgentArtifactPresentationKind.milkPlanCard => _AgentMilkManagementCard(
      card: card,
      cardType: card.artifactType ?? card.cardType ?? 'milk_plan_card',
    ),
    AgentArtifactPresentationKind.birthJourneyPlanCard =>
      _AgentBirthJourneyPlanCard(card: card),
    AgentArtifactPresentationKind.birthPlanCard =>
      card.specializedView is AgentBirthPlanCardView
          ? _AgentBirthPlanCard(
              card: card,
              data: card.specializedView! as AgentBirthPlanCardView,
            )
          : null,
    AgentArtifactPresentationKind.hospitalBagCard =>
      card.specializedView is AgentHospitalBagCardView
          ? _AgentHospitalBagCard(
              card: card,
              data: card.specializedView! as AgentHospitalBagCardView,
              onAction: onAction,
            )
          : null,
    _ => null,
  };
}

class _AgentUnsupportedArtifactCard extends StatelessWidget {
  const _AgentUnsupportedArtifactCard({required this.card});

  final AgentArtifactCardView card;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      key: ValueKey('agent-artifact-unsupported-${card.id}'),
      decoration: BoxDecoration(
        color: MomCozyColors.raised,
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: MomCozyColors.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: textTheme.titleSmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '当前 App 暂不支持此内容版本（${card.schemaVersion}）。',
                    style: textTheme.bodySmall?.copyWith(
                      color: MomCozyColors.mutedForeground,
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
}

class _AgentArtifactSpecializedShell extends StatelessWidget {
  const _AgentArtifactSpecializedShell({
    required this.card,
    required this.icon,
    required this.children,
    this.subtitle,
    this.statusLabel,
    this.accentColor = MomCozyColors.primary,
    this.showLogo = true,
  });

  final AgentArtifactCardView card;
  final IconData icon;
  final List<Widget> children;
  final String? subtitle;
  final String? statusLabel;
  final Color accentColor;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      key: ValueKey('agent-artifact-${card.id}'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: const Color(0xff2f1f29),
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            height: 1.3,
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(width: 8),
                  _AgentArtifactPill(label: statusLabel!, color: accentColor),
                ] else if (showLogo) ...[
                  const SizedBox(width: 8),
                  Image.asset(
                    MomCozyAssets.momcozyLogo,
                    width: 68,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ],
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentMilkManagementCard extends StatelessWidget {
  const _AgentMilkManagementCard({required this.card, required this.cardType});

  final AgentArtifactCardView card;
  final String cardType;

  @override
  Widget build(BuildContext context) {
    final cardJson = _effectiveCardJson(card);
    final isPlan = cardType == 'milk_plan_card';
    final subtitle = _displayString(cardJson['subtitle']);
    final headline = _displayString(cardJson['headline']);
    final statusLabel = isPlan
        ? null
        : _displayStringField(cardJson, 'status_label', 'statusLabel');
    final sections = _objectList(cardJson['sections']);

    return _AgentArtifactSpecializedShell(
      card: card,
      icon: isPlan ? Icons.route_rounded : Icons.water_drop_outlined,
      accentColor: isPlan ? MomCozyColors.care : MomCozyColors.violet,
      subtitle: subtitle,
      statusLabel: statusLabel,
      showLogo: false,
      children: [
        if (headline != null)
          _AgentArtifactBodyText(headline, weight: FontWeight.w700),
        for (final section in sections) ...[
          if (headline != null || section != sections.first)
            const SizedBox(height: 10),
          _AgentMilkSection(section: section),
        ],
      ],
    );
  }
}

class _AgentMilkSection extends StatelessWidget {
  const _AgentMilkSection({required this.section});

  final Map<String, Object?> section;

  @override
  Widget build(BuildContext context) {
    final title = _displayString(section['title']);
    final metrics = _objectList(section['metrics']);
    final items = _displayStringList(section['items']);

    return _AgentArtifactSection(
      title: title,
      children: [
        if (metrics.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                _AgentMetricTile(
                  label: _displayString(metric['label']) ?? '指标',
                  value: _displayString(metric['value']) ?? '-',
                  detail: _displayString(metric['detail']),
                ),
            ],
          ),
        if (items.isNotEmpty) ...[
          if (metrics.isNotEmpty) const SizedBox(height: 8),
          _AgentArtifactBulletList(items: items),
        ],
      ],
    );
  }
}

class _AgentBirthJourneyPlanCard extends StatelessWidget {
  const _AgentBirthJourneyPlanCard({required this.card});

  final AgentArtifactCardView card;

  @override
  Widget build(BuildContext context) {
    final cardJson = _effectiveCardJson(card);
    final owner = _mapField(cardJson, 'owner');
    final ownerChips = <({String label, String value})>[
      for (final entry in [
        (
          '孕期',
          _fieldValue(owner, 'current_week', 'currentWeek') ??
              _fieldValue(owner, 'due_date_or_week', 'dueDateOrWeek'),
        ),
        ('预产期预计', _fieldValue(owner, 'estimated_due_date', 'estimatedDueDate')),
        ('方式', _fieldValue(owner, 'birth_path', 'birthPath')),
        ('支持', _fieldValue(owner, 'support_person', 'supportPerson')),
        ('喂养', _fieldValue(owner, 'feeding_intention', 'feedingIntention')),
      ])
        if (_displayString(entry.$2) case final value?)
          (label: entry.$1, value: value),
    ].take(4).toList(growable: false);
    final todoPlan = _mapField(cardJson, 'todo_plan', 'todoPlan');
    final periods = _objectList(todoPlan['periods']);

    return _AgentArtifactSpecializedShell(
      card: card,
      icon: Icons.calendar_month_outlined,
      accentColor: MomCozyColors.primary,
      children: [
        if (ownerChips.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in ownerChips)
                _AgentOwnerChip(label: chip.label, value: chip.value),
            ],
          ),
        if (periods.isNotEmpty) ...[
          if (ownerChips.isNotEmpty) const SizedBox(height: 10),
          _AgentArtifactSection(
            children: [
              for (final period in periods) ...[
                _AgentBirthJourneyPeriod(
                  key: ValueKey(
                    'journey-period:${_displayString(period['id']) ?? _displayString(period['title']) ?? periods.indexOf(period)}',
                  ),
                  period: period,
                  initiallyExpanded:
                      period == periods.first ||
                      _displayString(period['status']) == 'current' ||
                      _displayStringField(
                            period,
                            'display_mode',
                            'displayMode',
                          ) ==
                          'expanded',
                ),
                if (period != periods.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _AgentBirthJourneyPeriod extends StatefulWidget {
  const _AgentBirthJourneyPeriod({
    super.key,
    required this.period,
    required this.initiallyExpanded,
  });

  final Map<String, Object?> period;
  final bool initiallyExpanded;

  @override
  State<_AgentBirthJourneyPeriod> createState() =>
      _AgentBirthJourneyPeriodState();
}

class _AgentBirthJourneyPeriodState extends State<_AgentBirthJourneyPeriod> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _displayString(widget.period['title']) ?? '阶段';
    final subtitle = _displayString(widget.period['subtitle']);
    final items = _objectList(widget.period['items']);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.labelLarge?.copyWith(
                              color: MomCozyColors.foreground,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            _AgentArtifactBodyText(subtitle),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AgentArtifactPill(
                      label: '${items.length} 个事项',
                      color: MomCozyColors.primary,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && items.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var index = 0; index < items.length; index++) ...[
                _AgentBirthJourneyItem(index: index + 1, item: items[index]),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentBirthJourneyItem extends StatelessWidget {
  const _AgentBirthJourneyItem({required this.index, required this.item});

  final int index;
  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _displayString(item['title']) ?? '事项';
    final priorityLabel = _displayStringField(
      item,
      'priority_label',
      'priorityLabel',
    );
    final reason = _displayString(item['reason']);
    final steps = _displayStringList(item['steps']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: MomCozyColors.raised,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 24,
            child: Center(
              child: Text(
                '$index',
                style: textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (priorityLabel != null)
                    _AgentArtifactPill(
                      label: priorityLabel,
                      color: priorityLabel == '建议'
                          ? MomCozyColors.care
                          : MomCozyColors.primary,
                    ),
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (reason != null) ...[
                const SizedBox(height: 4),
                _AgentArtifactBodyText(reason),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 6),
                _AgentArtifactBulletList(items: steps),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentBirthPlanCard extends StatelessWidget {
  const _AgentBirthPlanCard({required this.card, required this.data});

  final AgentArtifactCardView card;
  final AgentBirthPlanCardView data;

  @override
  Widget build(BuildContext context) {
    return _AgentArtifactSpecializedShell(
      card: card,
      icon: Icons.fact_check_outlined,
      accentColor: MomCozyColors.violet,
      children: [
        if (data.sections.isNotEmpty)
          _AgentArtifactSection(
            title: '沟通卡片内容',
            children: [
              for (final section in data.sections) ...[
                _AgentBirthPlanGroup(
                  section: section,
                  icon: _birthPlanSectionIcon(section.id),
                ),
                if (section != data.sections.last) const SizedBox(height: 8),
              ],
            ],
          ),
        if (data.medicalNotes.isNotEmpty) ...[
          if (data.sections.isNotEmpty) const SizedBox(height: 10),
          _AgentArtifactSection(
            title: '医疗或安全信息',
            children: [_AgentArtifactBulletList(items: data.medicalNotes)],
          ),
        ],
        const SizedBox(height: 10),
        _AgentArtifactBodyText(data.disclaimer),
      ],
    );
  }
}

class _AgentBirthPlanGroup extends StatelessWidget {
  const _AgentBirthPlanGroup({required this.section, required this.icon});

  final AgentBirthPlanSectionView section;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: MomCozyColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    section.title,
                    style: textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _AgentArtifactBulletList(items: section.values),
          ],
        ),
      ),
    );
  }
}

IconData _birthPlanSectionIcon(String id) {
  return switch (id) {
    'communication' => Icons.headphones_outlined,
    'labor_preferences' => Icons.directions_walk_rounded,
    'intervention_preferences' => Icons.health_and_safety_outlined,
    'pain_relief' => Icons.favorite_border_rounded,
    'baby_after_birth' => Icons.child_care_rounded,
    'if_plans_change' => Icons.medical_services_outlined,
    'emergency_authorization' => Icons.monitor_heart_outlined,
    'questions_for_hospital' => Icons.help_outline_rounded,
    _ => Icons.check_circle_outline_rounded,
  };
}

class _AgentHospitalBagCard extends StatelessWidget {
  const _AgentHospitalBagCard({
    required this.card,
    required this.data,
    this.onAction,
  });

  final AgentArtifactCardView card;
  final AgentHospitalBagCardView data;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  Widget build(BuildContext context) {
    return _AgentArtifactSpecializedShell(
      card: card,
      icon: Icons.shopping_bag_outlined,
      accentColor: MomCozyColors.care,
      subtitle: data.subtitle,
      children: [
        if (data.groups.isNotEmpty)
          _AgentArtifactSection(
            title: '物品清单',
            children: [
              for (final group in data.groups) ...[
                _AgentPackingGroup(
                  key: ValueKey('packing-group:${group.id}'),
                  group: group,
                  initiallyExpanded: group == data.groups.first,
                ),
                if (group != data.groups.last) const SizedBox(height: 8),
              ],
            ],
          ),
        if (data.disclaimer != null) ...[
          const SizedBox(height: 10),
          _AgentArtifactBodyText(data.disclaimer!),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: onAction == null
                ? null
                : () => onAction?.call(AgentArtifactActions.hospitalBagCart),
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text('打开购物车'),
            style: FilledButton.styleFrom(
              backgroundColor: MomCozyColors.care,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AgentPackingGroup extends StatefulWidget {
  const _AgentPackingGroup({
    super.key,
    required this.group,
    required this.initiallyExpanded,
  });

  final AgentHospitalBagGroupView group;
  final bool initiallyExpanded;

  @override
  State<_AgentPackingGroup> createState() => _AgentPackingGroupState();
}

class _AgentPackingGroupState extends State<_AgentPackingGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = widget.group.items;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.careSoft.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.care.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.group.title,
                        style: textTheme.labelLarge?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _AgentArtifactPill(
                      label: '${items.length}项',
                      color: MomCozyColors.care,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && items.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var index = 0; index < items.length; index++) ...[
                _AgentPackingItem(item: items[index]),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentPackingItem extends StatelessWidget {
  const _AgentPackingItem({required this.item});

  final AgentHospitalBagItemView item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: MomCozyColors.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox.square(
            dimension: 28,
            child: Icon(
              Icons.checkroom_outlined,
              size: 16,
              color: MomCozyColors.care,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    item.label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.meta != null)
                    Text(
                      item.meta!,
                      style: textTheme.labelMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (item.priorityLabel != null)
                    _AgentArtifactPill(
                      label: item.priorityLabel!,
                      color: item.priorityLabel == '和医院确认'
                          ? MomCozyColors.primary
                          : MomCozyColors.care,
                    ),
                ],
              ),
              if (item.description != null) ...[
                const SizedBox(height: 4),
                _AgentArtifactBodyText(item.description!),
              ],
              if (item.personalization != null) ...[
                const SizedBox(height: 4),
                _AgentArtifactBodyText(
                  item.personalization!,
                  weight: FontWeight.w700,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentArtifactSection extends StatelessWidget {
  const _AgentArtifactSection({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: textTheme.labelLarge?.copyWith(
              color: MomCozyColors.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...children,
      ],
    );
  }
}

class _AgentMetricTile extends StatelessWidget {
  const _AgentMetricTile({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MomCozyColors.muted.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.mutedForeground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.titleSmall?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentOwnerChip extends StatelessWidget {
  const _AgentOwnerChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: textTheme.labelMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentArtifactPill extends StatelessWidget {
  const _AgentArtifactPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AgentArtifactBodyText extends StatelessWidget {
  const _AgentArtifactBodyText(this.text, {this.weight});

  final String text;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        height: 1.35,
        color: MomCozyColors.mutedForeground,
        fontWeight: weight,
      ),
    );
  }
}

class _AgentArtifactBulletList extends StatelessWidget {
  const _AgentArtifactBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•',
                style: textTheme.bodySmall?.copyWith(
                  color: MomCozyColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: _AgentArtifactBodyText(item)),
            ],
          ),
          if (item != items.last) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

Map<String, Object?> _effectiveCardJson(AgentArtifactCardView card) {
  if (card.cardJson.isNotEmpty) return card.cardJson;
  final rawCardJson = _mapField(card.rawCard, 'card_json', 'cardJson');
  if (rawCardJson.isNotEmpty) return rawCardJson;
  return card.rawCard;
}

Object? _fieldValue(Map<String, Object?> map, String key, [String? alias]) {
  return map[key] ?? (alias == null ? null : map[alias]);
}

String? _displayStringField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  return _displayString(_fieldValue(map, key, alias));
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

String? _displayString(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    final values = _displayStringList(value);
    return values.isEmpty ? null : values.join('、');
  }
  return null;
}

List<String> _displayStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map(_displayString).whereType<String>().toList(growable: false);
}

Map<String, Object?> _mapField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  final value = map[key] ?? (alias == null ? null : map[alias]);
  return value is Map ? Map<String, Object?>.from(value) : const {};
}
