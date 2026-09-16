import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/mother_diary_controller.dart';
import 'diary_fields.dart';

enum DiarySection { rest, body, mood }

Future<void> showMotherDiaryEditor(
  BuildContext context, {
  required MotherDiaryRepository repository,
  required LocalDate date,
  DiarySection section = DiarySection.rest,
  MoodTone? initialMood,
  String? stageLabel,
  VoidCallback? onSaved,
}) async {
  final controller = MotherDiaryController(repository: repository, date: date);
  var open = true;
  unawaited(
    controller.load().then((_) {
      if (open && initialMood != null && controller.canEdit) {
        controller.edit(
          controller.draft.copyWith(
            mood: controller.draft.mood.copyWith(tone: () => initialMood),
          ),
        );
      }
    }),
  );
  try {
    await showDialog<void>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      barrierColor: const Color(0x55302723),
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Dialog(
          backgroundColor: MomHomeTokens.background,
          insetPadding: const EdgeInsets.all(MomCozySpacing.content),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              MediaQuery.sizeOf(context).width < 359 ? 18 : 24,
            ),
          ),
          child: SizedBox(
            width: MomCozyLayout.maxAppWidth,
            height: math.min(MediaQuery.sizeOf(context).height - 24, 800),
            child: MotherDiaryEditor(
              controller: controller,
              initialSection: section,
              stageLabel: stageLabel,
              onSaved: onSaved,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  } finally {
    open = false;
    controller.dispose();
  }
}

class MotherDiaryEditor extends StatefulWidget {
  const MotherDiaryEditor({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialSection = DiarySection.rest,
    this.stageLabel,
    this.onSaved,
  });
  final MotherDiaryController controller;
  final DiarySection initialSection;
  final String? stageLabel;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  @override
  State<MotherDiaryEditor> createState() => _MotherDiaryEditorState();
}

class _MotherDiaryEditorState extends State<MotherDiaryEditor> {
  late DiarySection _section = widget.initialSection;
  bool _saved = false;
  bool _emptyAttempt = false;
  bool _confirming = false;
  int _reloadRevision = 0;
  final _fieldsScroll = ScrollController();

  @override
  void dispose() {
    _fieldsScroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() => confirmDiscard(
    context,
    confirmLabel: '放弃修改',
    theme: momSettingsTheme(Theme.of(context)),
  );

  Future<void> _close() async {
    if (_confirming || widget.controller.phase == DiaryPhase.saving) return;
    _confirming = true;
    try {
      if (widget.controller.dirty && !await _confirmDiscard()) return;
      if (mounted) widget.onClose();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _save() async {
    if (widget.controller.canEdit && widget.controller.draft.isEmpty) {
      setState(() => _emptyAttempt = true);
      await _scrollToFeedback();
      return;
    }
    _emptyAttempt = false;
    if (await widget.controller.save() && mounted) {
      setState(() => _saved = true);
      widget.onSaved?.call();
    } else if (mounted && widget.controller.failure != null) {
      await _scrollToFeedback();
    }
  }

  Future<void> _scrollToFeedback() async {
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _fieldsScroll.hasClients) {
      await MomCozyMotion.scrollTo(
        context,
        _fieldsScroll,
        _fieldsScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _reloadConflict() async {
    if (await _confirmDiscard() && mounted) {
      // A fast repository load may finish before an intermediate loading frame.
      // Recreate the initial-value form after the user confirms discarding it.
      setState(() => _reloadRevision++);
      await widget.controller.reloadAfterConflict();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final title = switch (_section) {
        DiarySection.rest => '昨夜休息',
        DiarySection.body => '身体与精力',
        DiarySection.mood => '今日心情',
      };
      return PopScope(
        canPop: !controller.dirty && controller.phase != DiaryPhase.saving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_close());
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 540;
            final radius = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
              side: const BorderSide(color: MomHomeTokens.border),
            );
            return Theme(
              data: momSettingsTheme(Theme.of(context)).copyWith(
                expansionTileTheme: ExpansionTileThemeData(
                  backgroundColor: MomHomeTokens.surface,
                  collapsedBackgroundColor: MomHomeTokens.surface,
                  textColor: MomHomeTokens.ink,
                  collapsedTextColor: MomHomeTokens.ink,
                  iconColor: MomHomeTokens.secondary,
                  collapsedIconColor: MomHomeTokens.secondary,
                  shape: radius,
                  collapsedShape: radius,
                ),
              ),
              child: ColoredBox(
                color: MomHomeTokens.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: MomHomeTokens.surface,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: compact ? 8 : 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: MomHomeTokens.text(
                                  20,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: '关闭记录',
                              onPressed: controller.phase == DiaryPhase.saving
                                  ? null
                                  : _close,
                              style: IconButton.styleFrom(
                                foregroundColor: MomHomeTokens.rose,
                                minimumSize: const Size(44, 44),
                              ),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ColoredBox(
                      color: MomHomeTokens.surface,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          compact ? 10 : 14,
                        ),
                        child: _DiaryTabs(
                          completed: {
                            if (!controller.draft.rest.isEmpty)
                              DiarySection.rest,
                            if (!controller.draft.body.isEmpty)
                              DiarySection.body,
                            if (!controller.draft.mood.isEmpty)
                              DiarySection.mood,
                          },
                          selected: _section,
                          onSelected: controller.phase == DiaryPhase.saving
                              ? null
                              : (value) => setState(() => _section = value),
                        ),
                      ),
                    ),
                    Expanded(
                      child: switch (controller.phase) {
                        DiaryPhase.loading => const ProductLoadingView(),
                        DiaryPhase.failed => SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: ProductErrorView(
                            useMomStyle: true,
                            failure: controller.failure!,
                            onRetry: controller.load,
                          ),
                        ),
                        DiaryPhase.ready || DiaryPhase.saving => AbsorbPointer(
                          absorbing: controller.phase == DiaryPhase.saving,
                          child: SingleChildScrollView(
                            key: ValueKey(_section),
                            controller: _fieldsScroll,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _DiaryContext(
                                  section: _section,
                                  stageLabel: widget.stageLabel,
                                  date: controller.date,
                                  count: controller.draft.completedGroups,
                                ),
                                const SizedBox(height: MomHomeTokens.gap),
                                switch (_section) {
                                  DiarySection.rest => RestFields(
                                    value: controller.draft.rest,
                                    onChanged: (value) {
                                      _saved = false;
                                      controller.edit(
                                        controller.draft.copyWith(rest: value),
                                      );
                                    },
                                  ),
                                  DiarySection.body => BodyFields(
                                    key: ValueKey(_reloadRevision),
                                    value: controller.draft.body,
                                    onChanged: (value) {
                                      _saved = false;
                                      controller.edit(
                                        controller.draft.copyWith(body: value),
                                      );
                                    },
                                  ),
                                  DiarySection.mood => MoodFields(
                                    value: controller.draft.mood,
                                    onChanged: (value) {
                                      _saved = false;
                                      controller.edit(
                                        controller.draft.copyWith(mood: value),
                                      );
                                    },
                                  ),
                                },
                                if (_emptyAttempt && controller.draft.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: MomHomeTokens.gap,
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: MomSettingsCard(
                                        color: MomCozyColors.amberSoft,
                                        children: [
                                          Text(
                                            '先记录一项今天的状态，再保存。',
                                            style: MomHomeTokens.text(13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (controller.failure != null &&
                                    controller.phase != DiaryPhase.failed)
                                  ProductErrorView(
                                    useMomStyle: true,
                                    failure: controller.failure!,
                                    preserveDraft: true,
                                    onRetry:
                                        controller.failure!.kind ==
                                            ProductFailureKind.conflict
                                        ? _reloadConflict
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      },
                    ),
                    ColoredBox(
                      color: MomHomeTokens.surface,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: compact ? 10 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: MomHomeTokens.gap,
                          children: [
                            if (_saved)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  '今天的记录已保存',
                                  textAlign: TextAlign.center,
                                  style: MomHomeTokens.text(
                                    13,
                                    color: MomHomeTokens.teal,
                                  ),
                                ),
                              ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor:
                                    MomHomeTokens.neutralSurface,
                                disabledForegroundColor:
                                    MomHomeTokens.secondary,
                              ),
                              onPressed:
                                  controller.canSave ||
                                      (controller.canEdit &&
                                          controller.draft.isEmpty)
                                  ? _save
                                  : null,
                              child: Text(
                                controller.phase == DiaryPhase.saving
                                    ? '正在保存…'
                                    : '保存今天的记录',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _DiaryContext extends StatelessWidget {
  const _DiaryContext({
    required this.section,
    required this.stageLabel,
    required this.date,
    required this.count,
  });
  final DiarySection section;
  final String? stageLabel;
  final LocalDate date;
  final int count;

  @override
  Widget build(BuildContext context) => MomSettingsCard(
    gradient: switch (section) {
      DiarySection.rest => MomHomeTokens.sleep,
      DiarySection.body => MomHomeTokens.body,
      DiarySection.mood => MomHomeTokens.mood,
    },
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            '${stageLabel == null ? '' : '$stageLabel · '}${date.month}/${date.day}',
            style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
          ),
          Text(
            '$count/3 已记录',
            style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MomCozyLineIcon(
            switch (section) {
              DiarySection.rest => MomCozyLineGlyph.moon,
              DiarySection.body => MomCozyLineGlyph.heart,
              DiarySection.mood => MomCozyLineGlyph.spark,
            },
            size: 24,
            color: MomHomeTokens.teal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(switch (section) {
              DiarySection.rest => '休息的长短和感受，都值得被看见。',
              DiarySection.body => '慢慢感受，今天的身体需要什么。',
              DiarySection.mood => '不用急着变好，如实记录此刻的心情。',
            }, style: MomHomeTokens.text(13, color: MomHomeTokens.secondary)),
          ),
        ],
      ),
    ],
  );
}

class _DiaryTabs extends StatelessWidget {
  const _DiaryTabs({
    required this.selected,
    required this.onSelected,
    required this.completed,
  });
  final Set<DiarySection> completed;
  final DiarySection selected;
  final ValueChanged<DiarySection>? onSelected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: MomHomeTokens.neutralSurface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final value in DiarySection.values)
          Expanded(
            child: Semantics(
              selected: selected == value,
              child: TextButton(
                onPressed: onSelected == null ? null : () => onSelected!(value),
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.all(4),
                  foregroundColor: selected == value
                      ? MomHomeTokens.teal
                      : MomHomeTokens.secondary,
                  backgroundColor: selected == value
                      ? MomHomeTokens.mint
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: MomHomeTokens.text(13, weight: FontWeight.w700),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(switch (value) {
                        DiarySection.rest => '休息',
                        DiarySection.body => '身体',
                        DiarySection.mood => '心情',
                      }),
                    ),
                    if (completed.contains(value)) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        label: '已记录',
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected == value
                                ? MomHomeTokens.teal
                                : MomHomeTokens.secondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
