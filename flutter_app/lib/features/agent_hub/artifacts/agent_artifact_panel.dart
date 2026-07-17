import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_card_export.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/cards/agent_artifact_card_registry.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/card_export.dart';

class AgentArtifactPanel extends StatelessWidget {
  const AgentArtifactPanel({
    super.key,
    required this.cards,
    this.onAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.cardExportService = const PlatformAgentCardExportService(),
  });

  final List<AgentArtifactCardView> cards;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentCardExportService cardExportService;

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
    if (_isExportableSpecializedCard(card)) {
      return _AgentExportableArtifactCard(
        key: ValueKey('agent-card-export-wrapper-${card.id}'),
        card: card,
        exportService: cardExportService,
        builder: (exportControl) =>
            _specializedArtifactCard(
              card: card,
              onAction: onAction,
              exportControl: exportControl,
            ) ??
            _AgentArtifactGenericCard(card: card, onAction: onAction),
      );
    }
    return _specializedArtifactCard(card: card, onAction: onAction) ??
        _AgentArtifactGenericCard(card: card, onAction: onAction);
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
  Widget? exportControl,
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
            )
          : null,
    _ => null,
  };
}

bool _isExportableSpecializedCard(AgentArtifactCardView card) {
  return switch (card.presentationKind) {
    _ => false,
  };
}

typedef _ExportableArtifactCardBuilder = Widget Function(Widget? exportControl);

class _AgentExportableArtifactCard extends StatefulWidget {
  const _AgentExportableArtifactCard({
    super.key,
    required this.card,
    required this.exportService,
    required this.builder,
  });

  final AgentArtifactCardView card;
  final AgentCardExportService exportService;
  final _ExportableArtifactCardBuilder builder;

  @override
  State<_AgentExportableArtifactCard> createState() =>
      _AgentExportableArtifactCardState();
}

class _AgentExportableArtifactCardState
    extends State<_AgentExportableArtifactCard> {
  final GlobalKey _captureBoundaryKey = GlobalKey();
  bool _busy = false;
  bool _hideExportControl = false;

  @override
  Widget build(BuildContext context) {
    final exportControl = _hideExportControl
        ? null
        : OutlinedButton.icon(
            key: ValueKey('agent-card-export-${widget.card.id}'),
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(_busy ? '保存中' : '保存图片'),
          );

    return RepaintBoundary(
      key: _captureBoundaryKey,
      child: ColoredBox(
        color: Colors.white,
        child: widget.builder(exportControl),
      ),
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _hideExportControl = true;
    });
    try {
      await precacheImage(const AssetImage(MomCozyAssets.momcozyLogo), context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary = _captureBoundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final pixelRatio = MediaQuery.devicePixelRatioOf(
        context,
      ).clamp(2.0, 3.0).toDouble();
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) return;
        if (mounted) {
          setState(() => _hideExportControl = false);
        }
        await widget.exportService.sharePng(
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          filename: buildAgentCardExportFilename(
            cardType:
                widget.card.cardType ?? widget.card.artifactType ?? 'card',
            now: DateTime.now(),
          ),
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      // Export failures stay internal so the conversation remains uninterrupted.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _hideExportControl = false;
        });
      }
    }
  }
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
    final title = _displayString(cardJson['title']) ?? card.title;
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

    return DecoratedBox(
      key: ValueKey('agent-artifact-${card.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xebe8c4cf)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.58, 1],
          colors: [Color(0xfffffdfd), Color(0xfffffdf8), Color(0xfff8fffc)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 0.72,
                    colors: [Color(0x85ffebd6), Color(0x00ffebd6)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-1, -0.8),
                    radius: 0.68,
                    colors: [Color(0xade0f3ef), Color(0x00e0f3ef)],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LegacyBirthCardHeader(
                  title: title,
                  titleColor: const Color(0xff4a2635),
                  titleTopPadding: 4,
                  centerTitle: true,
                  borderColor: const Color(0xb8e8c4cf),
                  backgroundColors: const [
                    Color(0xf0ffeef4),
                    Color(0xe0fff7ed),
                    Color(0xe6eefaf7),
                  ],
                  accentColors: const [
                    Color(0xffd86b91),
                    Color(0xfff0b85b),
                    Color(0xff2c9b92),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ownerChips.isNotEmpty)
                        _BirthJourneyOwnerStrip(chips: ownerChips),
                      if (ownerChips.isNotEmpty && periods.isNotEmpty)
                        const SizedBox(height: 14),
                      if (periods.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < periods.length;
                                index++
                              ) ...[
                                _AgentBirthJourneyPeriod(
                                  key: ValueKey(
                                    'journey-period:${_displayString(periods[index]['id']) ?? _displayString(periods[index]['title']) ?? index}',
                                  ),
                                  period: periods[index],
                                  isFirst: index == 0,
                                ),
                                if (index != periods.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyBirthCardHeader extends StatelessWidget {
  const _LegacyBirthCardHeader({
    required this.title,
    required this.titleColor,
    required this.titleTopPadding,
    required this.centerTitle,
    required this.borderColor,
    required this.backgroundColors,
    required this.accentColors,
    this.middleStop = 0.62,
  });

  final String title;
  final Color titleColor;
  final double titleTopPadding;
  final bool centerTitle;
  final Color borderColor;
  final List<Color> backgroundColors;
  final List<Color> accentColors;
  final double middleStop;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Padding(
      padding: EdgeInsets.only(top: titleTopPadding),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: titleColor,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.12,
          letterSpacing: 0,
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, middleStop, 1],
          colors: backgroundColors,
        ),
      ),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: centerTitle
                        ? SizedBox(
                            height: 56,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: titleWidget,
                            ),
                          )
                        : titleWidget,
                  ),
                  const SizedBox(width: 10),
                  const _LegacyBirthCardLogo(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(colors: accentColors),
              ),
              child: const SizedBox(width: 86, height: 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyBirthCardLogo extends StatelessWidget {
  const _LegacyBirthCardLogo();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Image.asset(
          MomCozyAssets.momcozyLogo,
          width: 90,
          height: 50,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _BirthJourneyOwnerStrip extends StatelessWidget {
  const _BirthJourneyOwnerStrip({required this.chips});

  final List<({String label, String value})> chips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in chips)
              SizedBox(
                width: tileWidth,
                child: _BirthJourneyOwnerTile(
                  label: chip.label,
                  value: chip.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BirthJourneyOwnerTile extends StatelessWidget {
  const _BirthJourneyOwnerTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xade8c4cf)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: const Color(0xff8a6d7a),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xff3f2732),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentBirthJourneyPeriod extends StatefulWidget {
  const _AgentBirthJourneyPeriod({
    super.key,
    required this.period,
    required this.isFirst,
  });

  final Map<String, Object?> period;
  final bool isFirst;

  @override
  State<_AgentBirthJourneyPeriod> createState() =>
      _AgentBirthJourneyPeriodState();
}

class _AgentBirthJourneyPeriodState extends State<_AgentBirthJourneyPeriod> {
  late bool _expanded;

  bool get _startsExpanded {
    final displayMode = _displayStringField(
      widget.period,
      'display_mode',
      'displayMode',
    );
    final status = _displayString(widget.period['status']);
    final tone = _displayString(widget.period['tone']);
    return displayMode == 'expanded' ||
        status == 'current' ||
        tone == 'warm' ||
        widget.isFirst;
  }

  @override
  void initState() {
    super.initState();
    _expanded = _startsExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _displayString(widget.period['title']) ?? '阶段';
    final subtitle = _displayString(widget.period['subtitle']);
    final items = _objectList(widget.period['items']);
    final displayMode = _displayStringField(
      widget.period,
      'display_mode',
      'displayMode',
    );
    final status = _displayString(widget.period['status']);
    final tone = _displayString(widget.period['tone']);
    final isTerminal = displayMode == 'terminal';
    final isWarm =
        !isTerminal &&
        (tone == 'warm' ||
            displayMode == 'expanded' ||
            status == 'current' ||
            widget.isFirst);
    final borderColor = isTerminal
        ? const Color(0xd1cfc6de)
        : isWarm
        ? const Color(0xb8edb586)
        : const Color(0xebd8e1de);
    final backgroundColor = isTerminal
        ? const Color(0xe6fcfaff)
        : isWarm
        ? const Color(0xd1fff8ef)
        : const Color(0xc2fafffd);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
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
                              color: const Color(0xff352820),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: 0,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xff7b6a61),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${items.length} 个事项',
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xff4f8f87),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded && items.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < items.length;
                            index++
                          ) ...[
                            _AgentBirthJourneyItem(
                              index: index + 1,
                              item: items[index],
                            ),
                            if (index != items.length - 1)
                              const SizedBox(height: 7),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
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
    final reason = _displayString(item['reason']);
    final steps = _displayStringList(item['steps']);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xfffff0e4),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 20,
                child: Center(
                  child: Text(
                    '$index',
                    style: textTheme.labelSmall?.copyWith(
                      color: const Color(0xffb65c28),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
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
                  Text(
                    title,
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xff4f4540),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      reason,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xff7b6a61),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _BirthJourneyStepList(steps: steps),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthJourneyStepList extends StatelessWidget {
  const _BirthJourneyStepList({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xff8eb8b1),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 5),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  steps[index],
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xff5f514a),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (index != steps.length - 1) const SizedBox(height: 4),
        ],
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
    return DecoratedBox(
      key: ValueKey('agent-artifact-${card.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffd7e5e1)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.54, 1],
          colors: [Color(0xfffffdfd), Color(0xfff8fcfb), Color(0xfffffaf4)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.92, -1),
                    radius: 0.7,
                    colors: [Color(0x8cf2e0e7), Color(0x00f2e0e7)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-1, -0.76),
                    radius: 0.72,
                    colors: [Color(0xb3daf2ec), Color(0x00daf2ec)],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LegacyBirthCardHeader(
                  title: data.title,
                  titleColor: const Color(0xff3c2433),
                  titleTopPadding: 10,
                  centerTitle: false,
                  borderColor: const Color(0x2e537e77),
                  backgroundColors: const [
                    Color(0xe6eefcf7),
                    Color(0xc7fff3f7),
                    Color(0xccfff7e7),
                  ],
                  accentColors: const [
                    Color(0xff2c9b92),
                    Color(0xffd86b91),
                    Color(0xfff0b85b),
                  ],
                  middleStop: 0.54,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.sections.isNotEmpty)
                        _BirthPlanPanel(
                          title: '沟通卡片内容',
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < data.sections.length;
                                index++
                              ) ...[
                                _AgentBirthPlanGroup(
                                  section: data.sections[index],
                                  icon: _birthPlanSectionIcon(
                                    data.sections[index].id,
                                  ),
                                ),
                                if (index != data.sections.length - 1)
                                  const SizedBox(height: 9),
                              ],
                            ],
                          ),
                        ),
                      if (data.sections.isNotEmpty &&
                          data.medicalNotes.isNotEmpty)
                        const SizedBox(height: 14),
                      if (data.medicalNotes.isNotEmpty)
                        _BirthPlanPanel(
                          title: '医疗或安全信息',
                          child: _BirthPlanBulletList(items: data.medicalNotes),
                        ),
                      if (data.sections.isNotEmpty ||
                          data.medicalNotes.isNotEmpty)
                        const SizedBox(height: 14),
                      _BirthPlanDisclaimer(text: data.disclaimer),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthPlanPanel extends StatelessWidget {
  const _BirthPlanPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xe6dde8e5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff2c9b92), Color(0xffd86b91)],
                    ),
                  ),
                  child: SizedBox.square(dimension: 8),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xff4b2638),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
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
    final visual = _birthPlanGroupVisual(section.id);

    return DecoratedBox(
      key: ValueKey('birth-plan-group:${section.id}'),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: visual.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: visual.iconBackground,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Icon(icon, size: 14, color: visual.iconForeground),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.title,
                    style: textTheme.labelLarge?.copyWith(
                      color: const Color(0xff1f1f1f),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BirthPlanBulletList(items: section.values),
          ],
        ),
      ),
    );
  }
}

typedef _BirthPlanGroupVisual = ({
  Color border,
  Color background,
  Color iconBackground,
  Color iconForeground,
});

_BirthPlanGroupVisual _birthPlanGroupVisual(String id) {
  return switch (id) {
    'pain_relief' || 'emergency_authorization' => (
      border: const Color(0x42d86b91),
      background: const Color(0xd6fff6f9),
      iconBackground: const Color(0xffffe4ed),
      iconForeground: const Color(0xffbf4d78),
    ),
    'baby_after_birth' => (
      border: const Color(0x47e0a94a),
      background: const Color(0xe6fff9ed),
      iconBackground: const Color(0xfffff0cc),
      iconForeground: const Color(0xffa96d14),
    ),
    'labor_preferences' || 'if_plans_change' => (
      border: const Color(0x3d4b76b8),
      background: const Color(0xe0f6f8ff),
      iconBackground: const Color(0xffe5edff),
      iconForeground: const Color(0xff416bb2),
    ),
    'intervention_preferences' || 'questions_for_hospital' => (
      border: const Color(0x404a9c7c),
      background: const Color(0xe0f5fcf7),
      iconBackground: const Color(0xffe3f5e9),
      iconForeground: const Color(0xff397d58),
    ),
    _ => (
      border: const Color(0x422c9b92),
      background: const Color(0xdbf2fbf8),
      iconBackground: const Color(0xffdff6f2),
      iconForeground: const Color(0xff207b75),
    ),
  };
}

class _BirthPlanBulletList extends StatelessWidget {
  const _BirthPlanBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff2c9b92), Color(0xffd86b91)],
                    ),
                  ),
                  child: SizedBox.square(dimension: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items[index],
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff261c24),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (index != items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BirthPlanDisclaimer extends StatelessWidget {
  const _BirthPlanDisclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffe1e1e1))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xff666666),
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.45,
            letterSpacing: 0,
          ),
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
  const _AgentHospitalBagCard({required this.card, required this.data});

  final AgentArtifactCardView card;
  final AgentHospitalBagCardView data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('agent-artifact-${card.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffeadbe2)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.56, 1],
          colors: [Color(0xfffffafd), Color(0xfff8fcfb), Color(0xfffffaf2)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            const Positioned(
              top: -92,
              right: -84,
              child: SizedBox.square(
                dimension: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 0.78,
                      colors: [Color(0x99ffefdc), Color(0x00ffefdc)],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HospitalBagHeader(title: data.title, subtitle: data.subtitle),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.groups.isNotEmpty)
                        _HospitalBagListSection(groups: data.groups),
                      if (data.disclaimer != null) ...[
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xe1e1e1e1)),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data.disclaimer!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xff666666),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalBagHeader extends StatelessWidget {
  const _HospitalBagHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2eb8667b))),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.56, 1],
          colors: [Color(0xdbffebf1), Color(0xb8e8f9f6), Color(0xc7fff1da)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xff4b2638),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 13,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xff75636c),
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                height: 1.25,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  MomCozyAssets.momcozyLogo,
                  width: 90,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalBagListSection extends StatelessWidget {
  const _HospitalBagListSection({required this.groups});

  final List<AgentHospitalBagGroupView> groups;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xe6eadbe2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffd86b91), Color(0xff2c9ba5)],
                    ),
                  ),
                  child: SizedBox.square(dimension: 8),
                ),
                const SizedBox(width: 7),
                Text(
                  '物品清单',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xff4b2638),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (var index = 0; index < groups.length; index++) ...[
              _AgentPackingGroup(
                key: ValueKey('packing-group:${groups[index].id}'),
                group: groups[index],
                initiallyExpanded: index == 0,
              ),
              if (index != groups.length - 1) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
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
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xe0e4d9df)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ColoredBox(
                color: Color(0x732c9ba5),
                child: SizedBox(width: 4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 30),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: _expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xff2c9ba5),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.group.title,
                              style: textTheme.labelLarge?.copyWith(
                                color: const Color(0xff4b2638),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${items.length}项',
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(0xff6a6a6a),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _expanded && items.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < items.length;
                                  index++
                                ) ...[
                                  if (index > 0)
                                    const Divider(
                                      height: 1,
                                      color: Color(0xe6ebe2e7),
                                    ),
                                  _AgentPackingItem(
                                    item: items[index],
                                    group: widget.group,
                                    index: index,
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
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

class _AgentPackingItem extends StatelessWidget {
  const _AgentPackingItem({
    required this.item,
    required this.group,
    required this.index,
  });

  final AgentHospitalBagItemView item;
  final AgentHospitalBagGroupView group;
  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visual = _hospitalBagItemVisual(item, group);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                key: ValueKey('hospital-bag-item-icon:${group.id}:$index'),
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xbdffffff)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1f412a34),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SizedBox.square(
                  dimension: 20,
                  child: Icon(visual.icon, size: 13, color: visual.foreground),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff1f1f1f),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              if (item.meta != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 42),
                  child: Text(
                    item.meta!,
                    textAlign: TextAlign.right,
                    style: textTheme.labelMedium?.copyWith(
                      color: const Color(0xff4f4f4f),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (item.priorityLabel != null) ...[
                const SizedBox(width: 8),
                _HospitalBagPriorityTag(
                  priority: item.priority,
                  label: item.priorityLabel!,
                ),
              ],
            ],
          ),
          if (item.description != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                item.description!,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xff7a6b72),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (item.personalization != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                item.personalization!,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xff9c5a70),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HospitalBagPriorityTag extends StatelessWidget {
  const _HospitalBagPriorityTag({required this.priority, required this.label});

  final String? priority;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isMust = priority == 'must';
    final isConfirm = priority == 'confirm_first' || priority == '先确认';
    final background = isMust
        ? const Color(0xffd86b91)
        : isConfirm
        ? const Color(0xffe9f8f6)
        : const Color(0xfff5f5f5);
    final foreground = isMust
        ? Colors.white
        : isConfirm
        ? const Color(0xff176b76)
        : const Color(0xff333333);
    final border = isMust
        ? const Color(0xffd86b91)
        : isConfirm
        ? const Color(0x732c9ba5)
        : const Color(0xffd4d4d4);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

typedef _HospitalBagItemVisual = ({
  IconData icon,
  Color background,
  Color foreground,
});

_HospitalBagItemVisual _hospitalBagItemVisual(
  AgentHospitalBagItemView item,
  AgentHospitalBagGroupView group,
) {
  final label = item.label.toLowerCase();
  final text = '${group.id} ${group.title} ${item.label}'.toLowerCase();
  final confirmFirst =
      item.priority == 'confirm_first' || item.priority == '先确认';
  final icon = confirmFirst
      ? Icons.help_outline_rounded
      : _hospitalBagItemIcon(label: label, text: text);

  if (confirmFirst) {
    return (
      icon: icon,
      background: const Color(0xfff4e9ff),
      foreground: const Color(0xff8a4bc1),
    );
  }
  if (_matches(text, r'身份证|准生证|户口本|证件|产检|资料|医保|文件|复印|银行卡|现金|支付')) {
    return (
      icon: icon,
      background: const Color(0xfffff0c7),
      foreground: const Color(0xff9b6818),
    );
  }
  if (_matches(text, r'手机|充电|耳机|power bank|cable|通讯|随身')) {
    return (
      icon: icon,
      background: const Color(0xffdff5ff),
      foreground: const Color(0xff16779a),
    );
  }
  if (_matches(text, r'纸尿裤|湿巾|棉柔巾|包被|宝宝|帽子|袜子|安全座椅|安全提篮|出院衣物')) {
    return (
      icon: icon,
      background: const Color(0xffffe4ed),
      foreground: const Color(0xffc64f7a),
    );
  }
  if (_matches(text, r'出院外套|衣物|衣服|内裤|哺乳衣|睡衣|文胸|背心|拖鞋')) {
    return (
      icon: icon,
      background: const Color(0xffefe7ff),
      foreground: const Color(0xff7553c6),
    );
  }
  if (_matches(text, r'产褥垫|卫生巾|马桶垫|毛巾|纸巾|脸盆|洗发水|沐浴露|洗面奶|护肤|牙刷|牙膏')) {
    return (
      icon: icon,
      background: const Color(0xffddf7f0),
      foreground: const Color(0xff21886e),
    );
  }
  if (_matches(text, r'吸奶器|储奶|初乳|乳盾|乳头霜|防溢乳垫|奶瓶|配方奶|milk|哺乳')) {
    return (
      icon: icon,
      background: const Color(0xffe5f0ff),
      foreground: const Color(0xff376fbd),
    );
  }
  if (_matches(text, r'吸管杯|水杯|杯|餐具|零食|食物|能量|助产食品')) {
    return (
      icon: icon,
      background: const Color(0xfffff0d8),
      foreground: const Color(0xffb56a20),
    );
  }
  if (_matches(text, r'胎监带|收腹带|医生|医院|产后|常用药|药')) {
    return (
      icon: icon,
      background: const Color(0xffffe2de),
      foreground: const Color(0xffc4493d),
    );
  }
  if (_matches(text, r'停车|交通')) {
    return (
      icon: icon,
      background: const Color(0xffe9f6dd),
      foreground: const Color(0xff5c8f22),
    );
  }
  return (
    icon: icon,
    background: const Color(0xffe7f3f1),
    foreground: const Color(0xff287a78),
  );
}

IconData _hospitalBagItemIcon({required String label, required String text}) {
  if (_matches(label, r'身份证|护照|photo id|id card|陪产人.*身份|支持人.*身份')) {
    return Icons.badge_outlined;
  }
  if (_matches(label, r'医保|保险|insurance')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (_matches(label, r'产检|检查|报告|b超|超声|化验|病历|手册|资料')) {
    return Icons.assignment_outlined;
  }
  if (_matches(label, r'准生证|出生证明|birth certificate|证明|证书')) {
    return Icons.file_present_outlined;
  }
  if (_matches(label, r'户口本|户口')) return Icons.menu_book_outlined;
  if (_matches(label, r'复印|copy')) return Icons.copy_outlined;
  if (_matches(label, r'银行卡|信用卡|bank card|credit card')) {
    return Icons.credit_card_outlined;
  }
  if (_matches(label, r'现金|零钱|支付|移动支付|钱包')) {
    return Icons.payments_outlined;
  }
  if (_matches(label, r'文件|证件')) return Icons.description_outlined;
  if (_matches(label, r'手机|smartphone')) return Icons.smartphone_outlined;
  if (_matches(label, r'充电线|数据线|长充电线|cable')) {
    return Icons.cable_outlined;
  }
  if (_matches(label, r'充电器|插头|充电宝|电池|power bank')) {
    return Icons.battery_charging_full_rounded;
  }
  if (_matches(label, r'耳机|headphone')) return Icons.headphones_outlined;
  if (_matches(label, r'吸管杯|水杯|保温杯|杯')) {
    return Icons.local_drink_outlined;
  }
  if (_matches(label, r'餐具|餐盒|筷|勺|叉|零食|食物|能量|助产食品')) {
    return Icons.restaurant_outlined;
  }
  if (_matches(label, r'安全座椅|安全提篮|car seat')) {
    return Icons.directions_car_outlined;
  }
  if (_matches(label, r'纸尿裤|尿布|尿片|diaper')) {
    return Icons.child_care_outlined;
  }
  if (_matches(label, r'湿巾|棉柔巾|纸巾|wipe')) {
    return Icons.water_drop_outlined;
  }
  if (_matches(label, r'包被|襁褓|包巾|盖毯|blanket|swaddle')) {
    return Icons.bed_outlined;
  }
  if (_matches(label, r'帽子|帽')) return Icons.circle_outlined;
  if (_matches(label, r'袜子|袜|鞋|拖鞋')) return Icons.directions_walk_outlined;
  if (_matches(label, r'连体衣|和尚服|新生儿衣|宝宝.*衣|出院衣物')) {
    return Icons.child_friendly_outlined;
  }
  if (_matches(label, r'哺乳文胸|文胸|内衣|内裤|一次性内裤|睡衣|哺乳衣|衣物|衣服|出院外套|外套|背心')) {
    return Icons.checkroom_outlined;
  }
  if (_matches(label, r'产褥垫|护理垫|卫生巾')) {
    return Icons.water_drop_outlined;
  }
  if (_matches(label, r'马桶垫|坐便')) return Icons.cleaning_services_outlined;
  if (_matches(label, r'毛巾|浴巾|洗发|沐浴|洗面奶|护肤|冲洗瓶|脸盆|盆')) {
    return Icons.bathtub_outlined;
  }
  if (_matches(label, r'牙刷|牙膏|梳子')) return Icons.brush_outlined;
  if (_matches(label, r'吸奶器|奶瓶|奶嘴|配方奶|奶粉|初乳|milk')) {
    return Icons.local_drink_outlined;
  }
  if (_matches(label, r'储奶袋|储奶瓶|储奶')) return Icons.inventory_2_outlined;
  if (_matches(label, r'乳头霜|乳头膏|防溢乳垫|乳盾')) {
    return Icons.favorite_border_rounded;
  }
  if (_matches(label, r'哺乳枕')) return Icons.chair_outlined;
  if (_matches(label, r'胎监带|胎心|胎动')) return Icons.monitor_heart_outlined;
  if (_matches(label, r'收腹带|束腹带')) return Icons.health_and_safety_outlined;
  if (_matches(label, r'体温计|温度计')) return Icons.thermostat_outlined;
  if (_matches(label, r'常用药|止痛|处方|药')) return Icons.medication_outlined;
  if (_matches(label, r'医生|医院|住院|产后')) return Icons.local_hospital_outlined;
  if (_matches(label, r'停车')) return Icons.local_parking_rounded;
  if (_matches(label, r'路线|交通|打车|出租|车')) return Icons.route_outlined;
  if (_matches(label, r'陪产人|支持人')) return Icons.work_outline_rounded;
  if (_matches(label, r'行李|包|收纳')) return Icons.luggage_outlined;
  if (_matches(text, r'纸尿裤|湿巾|棉柔巾|包被|宝宝|帽子|袜子|安全座椅|安全提篮|出院衣物')) {
    return Icons.child_friendly_outlined;
  }
  if (_matches(text, r'出院外套|衣物|衣服|内裤|哺乳衣|睡衣|文胸|背心|拖鞋')) {
    return Icons.checkroom_outlined;
  }
  if (_matches(text, r'吸奶器|储奶|初乳|乳盾|乳头霜|防溢乳垫|奶瓶|配方奶|milk|哺乳')) {
    return Icons.local_drink_outlined;
  }
  return Icons.inventory_2_outlined;
}

bool _matches(String value, String pattern) => RegExp(pattern).hasMatch(value);

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
