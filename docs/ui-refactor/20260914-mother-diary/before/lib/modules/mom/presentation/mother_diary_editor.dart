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
          backgroundColor: MomCozyColors.warmFormSurface,
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
  final _fieldsScroll = ScrollController();

  @override
  void dispose() {
    _fieldsScroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() =>
      confirmDiscard(context, confirmLabel: '放弃修改');

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
            final narrow = MediaQuery.sizeOf(context).width < 359;
            final compact = constraints.maxHeight < 540;
            final radius = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: MomCozyColors.warmFormBorder),
            );
            return Theme(
              data: Theme.of(context).copyWith(
                expansionTileTheme: ExpansionTileThemeData(
                  backgroundColor: MomCozyColors.warmQuietSurface,
                  collapsedBackgroundColor: MomCozyColors.warmQuietSurface,
                  textColor: MomCozyColors.diaryInk,
                  collapsedTextColor: MomCozyColors.diaryInk,
                  iconColor: MomCozyColors.diaryMuted,
                  collapsedIconColor: MomCozyColors.diaryMuted,
                  shape: radius,
                  collapsedShape: radius,
                ),
                inputDecorationTheme: Theme.of(context).inputDecorationTheme
                    .copyWith(
                      fillColor: MomCozyColors.warmFormField,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: MomCozyColors.warmFormBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: MomCozyColors.diarySelectionBorder,
                        ),
                      ),
                    ),
              ),
              child: ColoredBox(
                color: MomCozyColors.warmFormSurface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DiaryHeader(
                      title: title,
                      section: _section,
                      stageLabel: widget.stageLabel,
                      date: controller.date,
                      count: controller.draft.completedGroups,
                      compact: compact,
                      onClose: controller.phase == DiaryPhase.saving
                          ? null
                          : _close,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 14 : 20,
                          compact ? 10 : 18,
                          narrow ? 14 : 20,
                          compact ? 10 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DiaryTabs(
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
                                  : (value) => setState(() {
                                      _section = value;
                                    }),
                            ),
                            SizedBox(height: compact ? 10 : 16),
                            Expanded(
                              child: switch (controller.phase) {
                                DiaryPhase.loading =>
                                  const ProductLoadingView(),
                                DiaryPhase.failed => SingleChildScrollView(
                                  child: ProductErrorView(
                                    failure: controller.failure!,
                                    onRetry: controller.load,
                                  ),
                                ),
                                DiaryPhase.ready ||
                                DiaryPhase.saving => AbsorbPointer(
                                  absorbing:
                                      controller.phase == DiaryPhase.saving,
                                  child: SingleChildScrollView(
                                    key: ValueKey(_section),
                                    controller: _fieldsScroll,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        switch (_section) {
                                          DiarySection.rest => RestFields(
                                            value: controller.draft.rest,
                                            onChanged: (value) {
                                              _saved = false;
                                              controller.edit(
                                                controller.draft.copyWith(
                                                  rest: value,
                                                ),
                                              );
                                            },
                                          ),
                                          DiarySection.body => BodyFields(
                                            value: controller.draft.body,
                                            onChanged: (value) {
                                              _saved = false;
                                              controller.edit(
                                                controller.draft.copyWith(
                                                  body: value,
                                                ),
                                              );
                                            },
                                          ),
                                          DiarySection.mood => MoodFields(
                                            value: controller.draft.mood,
                                            onChanged: (value) {
                                              _saved = false;
                                              controller.edit(
                                                controller.draft.copyWith(
                                                  mood: value,
                                                ),
                                              );
                                            },
                                          ),
                                        },
                                        if (_emptyAttempt &&
                                            controller.draft.isEmpty)
                                          Semantics(
                                            liveRegion: true,
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: MomCozyColors.amberSoft,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      MomCozyRadii.control,
                                                    ),
                                              ),
                                              child: const Text(
                                                '先记录一项今天的状态，再保存。',
                                              ),
                                            ),
                                          ),
                                        if (controller.failure != null &&
                                            controller.phase !=
                                                DiaryPhase.failed)
                                          ProductErrorView(
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
                            if (_saved)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Semantics(
                                  liveRegion: true,
                                  child: const Text(
                                    '今天的记录已保存',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: MomCozyColors.care,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed:
                                  controller.canSave ||
                                      (controller.canEdit &&
                                          controller.draft.isEmpty)
                                  ? _save
                                  : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                backgroundColor: MomCozyColors.diaryHeader,
                                foregroundColor: MomCozyColors.diaryBright,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: MomCozyTypography.fontFamily,
                                  fontFamilyFallback:
                                      MomCozyTypography.fontFamilyFallback,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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

class _DiaryHeader extends StatelessWidget {
  const _DiaryHeader({
    required this.title,
    required this.section,
    required this.stageLabel,
    required this.date,
    required this.count,
    required this.compact,
    required this.onClose,
  });
  final String title;
  final DiarySection section;
  final String? stageLabel;
  final LocalDate date;
  final int count;
  final bool compact;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 359 ? 17 : 22,
      compact ? 8 : 18,
      22,
      compact ? 8 : 23,
    ),
    color: MomCozyColors.diaryHeader,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: MomCozyTypography.displayFontFamily,
                  fontSize: compact ? 19 : 23,
                  height: 1.2,
                  letterSpacing: -.69,
                  fontWeight: FontWeight.w600,
                  color: MomCozyColors.diaryBright,
                ),
              ),
            ),
            IconButton(
              tooltip: '关闭记录',
              onPressed: onClose,
              style: IconButton.styleFrom(
                foregroundColor: MomCozyColors.diaryBright,
                side: const BorderSide(color: Color(0x669d8877)),
                minimumSize: const Size(44, 44),
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.close,
                size: 20,
                color: MomCozyColors.diaryBright,
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                '${stageLabel == null ? '' : '$stageLabel · '}${date.month}/${date.day}',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: MomCozyColors.diaryMeta,
                ),
              ),
              Text(
                '$count/3 已记录',
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: MomCozyColors.diaryMeta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 62),
                child: Text(
                  switch (section) {
                    DiarySection.rest => '休息的长短和感受，都值得被看见。',
                    DiarySection.body => '慢慢感受，今天的身体需要什么。',
                    DiarySection.mood => '不用急着变好，如实记录此刻的心情。',
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: MomCozyColors.diaryBright,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: -5,
                child: MomCozyLineIcon(
                  switch (section) {
                    DiarySection.rest => MomCozyLineGlyph.moon,
                    DiarySection.body => MomCozyLineGlyph.heart,
                    DiarySection.mood => MomCozyLineGlyph.spark,
                  },
                  size: 46,
                  color: const Color(0xb3d2b89f),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
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
      color: MomCozyColors.warmFormTab,
      borderRadius: BorderRadius.circular(13),
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
                      ? MomCozyColors.diaryBright
                      : MomCozyColors.diaryMuted,
                  backgroundColor: selected == value
                      ? MomCozyColors.warmFormSelected
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: MomCozyTypography.fontFamily,
                    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
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
                                ? MomCozyColors.diaryMeta
                                : MomCozyColors.diaryMuted,
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
