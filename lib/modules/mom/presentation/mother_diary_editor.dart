import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../application/mother_diary_controller.dart';
import 'diary_fields.dart';

enum DiarySection { rest, body, mood }

Future<void> showMotherDiaryEditor(
  BuildContext context, {
  required MotherDiaryRepository repository,
  required LocalDate date,
  DiarySection section = DiarySection.rest,
  VoidCallback? onSaved,
}) async {
  final controller = MotherDiaryController(repository: repository, date: date);
  unawaited(controller.load());
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: MomCozyColors.background,
        insetPadding: const EdgeInsets.all(MomCozySpacing.content),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.dialog),
        ),
        child: SizedBox(
          width: MomCozyLayout.maxAppWidth,
          height: math.min(MediaQuery.sizeOf(context).height * .86, 760),
          child: MotherDiaryEditor(
            controller: controller,
            initialSection: section,
            onSaved: onSaved,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

class MotherDiaryEditor extends StatefulWidget {
  const MotherDiaryEditor({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialSection = DiarySection.rest,
    this.onSaved,
  });
  final MotherDiaryController controller;
  final DiarySection initialSection;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  @override
  State<MotherDiaryEditor> createState() => _MotherDiaryEditorState();
}

class _MotherDiaryEditorState extends State<MotherDiaryEditor> {
  late DiarySection _section = widget.initialSection;
  bool _saved = false;
  bool _confirming = false;
  final _fieldsScroll = ScrollController();

  @override
  void dispose() {
    _fieldsScroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('离开这次记录？'),
          content: const Text('还未保存的修改会被放弃。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续填写'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      ) ??
      false;

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
    if (await widget.controller.save() && mounted) {
      setState(() => _saved = true);
      widget.onSaved?.call();
    } else if (mounted && widget.controller.failure != null) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _fieldsScroll.hasClients) {
        await _fieldsScroll.animateTo(
          _fieldsScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: MomCozyTypography.headingSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭记录',
                    onPressed: controller.phase == DiaryPhase.saving
                        ? null
                        : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: MomCozySpacing.headingGap,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: MomCozySpacing.content,
                  children: [
                    Text(
                      '${controller.date.month}/${controller.date.day}',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                    Text(
                      '${controller.draft.completedGroups}/3 已记录',
                      style: const TextStyle(color: MomCozyColors.primaryDark),
                    ),
                  ],
                ),
              ),
              SegmentedButton<DiarySection>(
                segments: const [
                  ButtonSegment(value: DiarySection.rest, label: Text('休息')),
                  ButtonSegment(value: DiarySection.body, label: Text('身体')),
                  ButtonSegment(value: DiarySection.mood, label: Text('心情')),
                ],
                selected: {_section},
                showSelectedIcon: false,
                onSelectionChanged: controller.phase == DiaryPhase.saving
                    ? null
                    : (value) => setState(() => _section = value.single),
              ),
              const SizedBox(height: MomCozySpacing.section),
              Expanded(
                child: switch (controller.phase) {
                  DiaryPhase.loading => const ProductLoadingView(),
                  DiaryPhase.failed => SingleChildScrollView(
                    child: ProductErrorView(
                      failure: controller.failure!,
                      onRetry: controller.load,
                    ),
                  ),
                  DiaryPhase.ready || DiaryPhase.saving => AbsorbPointer(
                    absorbing: controller.phase == DiaryPhase.saving,
                    child: SingleChildScrollView(
                      key: ValueKey(_section),
                      controller: _fieldsScroll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          if (controller.failure != null &&
                              controller.phase != DiaryPhase.failed)
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
                  padding: const EdgeInsets.only(top: MomCozySpacing.content),
                  child: Semantics(
                    liveRegion: true,
                    child: const Text(
                      '今天的记录已保存',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MomCozyColors.care),
                    ),
                  ),
                ),
              const SizedBox(height: MomCozySpacing.headingGap),
              MomCozyPrimaryButton(
                onPressed: controller.canSave ? _save : null,
                child: Text(
                  controller.phase == DiaryPhase.saving ? '正在保存…' : '保存今天的记录',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
