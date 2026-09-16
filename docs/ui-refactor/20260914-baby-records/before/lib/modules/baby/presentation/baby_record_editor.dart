import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/choice_field.dart';
import '../../../shared/widgets/warm_editor_header.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/baby_record_editor_controller.dart';
import 'baby_labels.dart';
import 'baby_record_fields.dart';

Future<List<BabyRecord>?> showBabyRecordEditor(
  BuildContext context, {
  required BabyRecordRepository repository,
  required BabyProfile baby,
  required String timezone,
  required DateTime Function() now,
  required BabyRecordKind kind,
  BabyRecord? initial,
  BabySleepRecord? activeSleep,
  DiaperKind? diaperKind,
  GrowthMetric growthMetric = GrowthMetric.weight,
}) async {
  final controller = BabyRecordEditorController(
    repository: repository,
    baby: baby,
    timezone: timezone,
    now: now,
    kind: kind,
    initial: initial,
    activeSleep: activeSleep,
    diaperKind: diaperKind,
    growthMetric: growthMetric,
  );
  try {
    return await showDialog<List<BabyRecord>>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (context) => BabyRecordEditor(controller: controller),
    );
  } finally {
    controller.dispose();
  }
}

enum _StatusTab { sleep, wet, stool }

class BabyRecordEditor extends StatefulWidget {
  const BabyRecordEditor({super.key, required this.controller});
  final BabyRecordEditorController controller;
  @override
  State<BabyRecordEditor> createState() => _BabyRecordEditorState();
}

class _BabyRecordEditorState extends State<BabyRecordEditor> {
  bool _allowPop = false, _closing = false;
  final _scroll = ScrollController();
  Future<void> _close([List<BabyRecord>? saved]) async {
    final c = widget.controller;
    if (c.busy || _closing) return;
    _closing = true;
    if (saved == null &&
        (c.dirty || c.uncertain) &&
        !await confirmDiscard(context, uncertainSave: c.uncertain)) {
      _closing = false;
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, saved);
  }

  Future<void> _save() async {
    final c = widget.controller;
    if (c.editable &&
        c.hasActiveSleep &&
        !c.editing &&
        c.sleepEndedAt == null) {
      c.setSleepEnd(c.now());
    }
    final saved = await c.save();
    if (!mounted) return;
    if (saved != null) {
      await _close(saved);
    } else {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _scroll.hasClients) {
        await MomCozyMotion.scrollTo(
          context,
          _scroll,
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<List<BabyRecord>>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Dialog(
      backgroundColor: MomCozyColors.warmFormSurface,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            final status =
                c.kind == BabyRecordKind.sleep ||
                c.kind == BabyRecordKind.diaper;
            return Column(
              mainAxisSize: status ? MainAxisSize.max : MainAxisSize.min,
              children: [
                WarmEditorHeader(
                  title: c.editing
                      ? '编辑${babyRecordLabels[c.kind]}'
                      : status
                      ? '记录今日状态'
                      : c.kind == BabyRecordKind.growth
                      ? '生长发育记录'
                      : c.kind == BabyRecordKind.feeding
                      ? '记录今日吃奶'
                      : '记录${babyRecordLabels[c.kind]}',
                  closeLabel: '关闭记录',
                  onClose: c.busy ? null : _close,
                ),
                Flexible(
                  fit: status ? FlexFit.tight : FlexFit.loose,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (status && !c.editing)
                          ChoiceField(
                            title: '',
                            style: ChoiceFieldStyle.warmSegmented,
                            options: const {
                              _StatusTab.sleep: '睡眠',
                              _StatusTab.wet: '尿湿',
                              _StatusTab.stool: '便便',
                            },
                            selected: {
                              c.kind == BabyRecordKind.sleep
                                  ? _StatusTab.sleep
                                  : c.diaperKind == DiaperKind.wet
                                  ? _StatusTab.wet
                                  : _StatusTab.stool,
                            },
                            onChanged: (value) {
                              if (!c.editable || value.isEmpty) return;
                              final tab = value.first;
                              if (tab == _StatusTab.sleep) {
                                c.setKind(BabyRecordKind.sleep);
                              } else {
                                c.setKind(
                                  BabyRecordKind.diaper,
                                  diaper: tab == _StatusTab.wet
                                      ? DiaperKind.wet
                                      : DiaperKind.dirty,
                                );
                              }
                            },
                          ),
                        BabyRecordFields(controller: c),
                        if (c.validation != null)
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                top: MomCozySpacing.content,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: MomCozyColors.recordValidationSurface,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                c.validation!,
                                style: const TextStyle(
                                  color: MomCozyColors.recordValidationInk,
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        if (c.failure != null)
                          ProductErrorView(
                            failure: c.failure!,
                            preserveDraft: true,
                          ),
                        if (c.failure?.code == 'active_sleep_exists')
                          const Text('已有一段睡眠还未结束。请关闭并刷新宝宝页，先记录醒来时间。')
                        else if (c.failure?.kind == ProductFailureKind.conflict)
                          const Text('请保留需要的内容，关闭后刷新历史记录，再打开最新记录核对。'),
                        if (c.uncertain)
                          const Text('保存结果还未确认。请重试确认这次保存后再修改内容。'),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(
                        height: 1,
                        color: MomCozyColors.warmFormBorder,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        key: const ValueKey('baby-save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MomCozyColors.diaryHeader,
                          foregroundColor: MomCozyColors.diaryBright,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(fontSize: 14),
                        ),
                        onPressed: c.busy ? null : _save,
                        child: Text(
                          c.busy
                              ? '正在保存…'
                              : c.uncertain
                              ? '重试确认保存'
                              : c.hasActiveSleep &&
                                    !c.editing &&
                                    c.sleepEndedAt == null
                              ? '记录醒来时间为现在'
                              : c.editing
                              ? '保存记录'
                              : switch (c.kind) {
                                  BabyRecordKind.feeding => '保存这次喂养',
                                  BabyRecordKind.sleep =>
                                    c.sleepEndedAt == null
                                        ? '开始记录这段睡眠'
                                        : '保存这段睡眠',
                                  BabyRecordKind.diaper => '保存这次记录',
                                  BabyRecordKind.growth => '保存',
                                  BabyRecordKind.development => '保存发育观察',
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
