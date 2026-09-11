import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
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
      barrierDismissible: false,
      builder: (context) => BabyRecordEditor(controller: controller),
    );
  } finally {
    controller.dispose();
  }
}

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
      if (_scroll.hasClients) {
        await _scroll.animateTo(
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
      backgroundColor: MomCozyColors.background,
      insetPadding: const EdgeInsets.all(MomCozySpacing.content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.dialog),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MomCozyLayout.maxAppWidth,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            final status =
                c.kind == BabyRecordKind.sleep ||
                c.kind == BabyRecordKind.diaper;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: MomCozyInsets.editorHeader,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.editing
                              ? '编辑${babyRecordLabels[c.kind]}'
                              : status
                              ? '记录今日状态'
                              : '记录${babyRecordLabels[c.kind]}',
                          style: const TextStyle(
                            fontSize: MomCozyTypography.headingSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭记录',
                        onPressed: c.busy ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: MomCozyInsets.editorBody,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '这次记录属于 ${c.baby.name}',
                          style: const TextStyle(
                            fontSize: MomCozyTypography.captionSize,
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: MomCozySpacing.page),
                        if (status && !c.editing)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: MomCozySpacing.page,
                            ),
                            child: Wrap(
                              spacing: MomCozySpacing.compact,
                              runSpacing: MomCozySpacing.xs,
                              children: [
                                ChoiceChip(
                                  label: const Text('睡眠'),
                                  selected: c.kind == BabyRecordKind.sleep,
                                  onSelected: c.editable
                                      ? (_) => c.setKind(BabyRecordKind.sleep)
                                      : null,
                                ),
                                ChoiceChip(
                                  label: const Text('尿湿'),
                                  selected:
                                      c.kind == BabyRecordKind.diaper &&
                                      c.diaperKind == DiaperKind.wet,
                                  onSelected: c.editable
                                      ? (_) => c.setKind(
                                          BabyRecordKind.diaper,
                                          diaper: DiaperKind.wet,
                                        )
                                      : null,
                                ),
                                ChoiceChip(
                                  label: const Text('便便'),
                                  selected:
                                      c.kind == BabyRecordKind.diaper &&
                                      c.diaperKind != DiaperKind.wet,
                                  onSelected: c.editable
                                      ? (_) => c.setKind(
                                          BabyRecordKind.diaper,
                                          diaper: DiaperKind.dirty,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        BabyRecordFields(controller: c),
                        if (c.validation != null)
                          Semantics(
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: MomCozySpacing.content,
                              ),
                              child: Text(
                                c.validation!,
                                style: const TextStyle(
                                  color: MomCozyColors.danger,
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
                        const SizedBox(height: MomCozySpacing.card),
                        FilledButton(
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
                                : '保存记录',
                          ),
                        ),
                      ],
                    ),
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
