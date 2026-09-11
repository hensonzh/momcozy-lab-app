import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_card_export.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/cards/agent_artifact_card_registry.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/card_export.dart';

class AgentArtifactPanel extends StatelessWidget {
  const AgentArtifactPanel({
    super.key,
    required this.cards,
    this.onAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.formPresentationSession,
    this.autoPresentForms = false,
    this.cardExportService = const PlatformAgentCardExportService(),
  });

  final List<AgentArtifactCardView> cards;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession? formPresentationSession;
  final bool autoPresentForms;
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MomCozySurface(
      key: ValueKey('agent-artifact-card-${card.id}'),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: MomCozyInsets.compactCard,
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
        color: MomCozyColors.card,
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
    return MomCozySurface(
      key: ValueKey('agent-artifact-unsupported-${card.id}'),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: MomCozyInsets.compactCard,
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
