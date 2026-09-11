import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/baby_profile_controller.dart';
import 'baby_labels.dart';

Future<BabyProfile?> showBabyProfileEditor(
  BuildContext context, {
  required BabyProfileRepository repository,
  required String timezone,
  required DateTime Function() now,
  BabyProfile? profile,
}) async {
  final controller = BabyProfileController(
    repository: repository,
    timezone: timezone,
    now: now,
    initial: profile,
  );
  try {
    return await showDialog<BabyProfile>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BabyProfileEditor(controller: controller),
    );
  } finally {
    controller.dispose();
  }
}

class BabyProfileEditor extends StatefulWidget {
  const BabyProfileEditor({super.key, required this.controller});
  final BabyProfileController controller;
  @override
  State<BabyProfileEditor> createState() => _BabyProfileEditorState();
}

class _BabyProfileEditorState extends State<BabyProfileEditor> {
  late final _name = TextEditingController(text: widget.controller.name);
  bool _allowPop = false, _closing = false;
  Future<void> _close([BabyProfile? saved]) async {
    final c = widget.controller;
    if (_closing || c.busy) return;
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

  Future<void> _date() async {
    final c = widget.controller;
    final birth = c.birthDate;
    final selected = birth != null && birth.compareTo(c.today) <= 0
        ? birth
        : c.today;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(selected.year, selected.month, selected.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(c.today.year, c.today.month, c.today.day),
      helpText: '宝宝出生日期',
    );
    if (date != null && mounted) c.setBirthDate(LocalDate.fromDateTime(date));
  }

  Future<void> _save() async {
    final saved = await widget.controller.save();
    if (saved != null && mounted) await _close(saved);
  }

  Future<void> _reload() async {
    if (await widget.controller.reload() && mounted) {
      _name.text = widget.controller.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<BabyProfile>(
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
        constraints: const BoxConstraints(maxWidth: MomCozyLayout.maxAppWidth),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: MomCozyInsets.editorHeader,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.isNew ? '添加宝宝' : '宝宝资料',
                          style: const TextStyle(
                            fontSize: MomCozyTypography.headingSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭宝宝资料',
                        onPressed: c.busy ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: MomCozyInsets.editorBody,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _name,
                          enabled: c.editable,
                          maxLength: 120,
                          onChanged: c.setName,
                          decoration: const InputDecoration(
                            labelText: '宝宝称呼',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: MomCozySpacing.page),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('出生日期'),
                          subtitle: Text(c.birthDate?.toString() ?? '尚未登记'),
                          trailing: const Icon(Icons.calendar_month_outlined),
                          onTap: c.editable ? _date : null,
                        ),
                        if (c.birthDate != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: c.editable
                                  ? () => c.setBirthDate(null)
                                  : null,
                              child: const Text('清除日期'),
                            ),
                          ),
                        const SizedBox(height: MomCozySpacing.compact),
                        const Text(
                          '出生记录性别',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          '用于匹配生长参考范围',
                          style: TextStyle(
                            color: MomCozyColors.mutedForeground,
                            fontSize: MomCozyTypography.captionSize,
                          ),
                        ),
                        const SizedBox(height: MomCozySpacing.compact),
                        Wrap(
                          spacing: MomCozySpacing.compact,
                          runSpacing: MomCozySpacing.xs,
                          children: [
                            for (final sex in BabySex.values)
                              ChoiceChip(
                                label: Text(
                                  sex == BabySex.unspecified
                                      ? '暂不填写'
                                      : babySexLabel(sex),
                                ),
                                selected: c.sex == sex,
                                onSelected: c.editable
                                    ? (_) => c.setSex(sex)
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: MomCozySpacing.page),
                        DropdownButtonFormField<FeedingMode>(
                          initialValue: c.feedingMode,
                          key: ValueKey(c.feedingMode),
                          isExpanded: true,
                          itemHeight: null,
                          decoration: const InputDecoration(
                            labelText: '目前喂养方式',
                          ),
                          items: [
                            for (final mode in FeedingMode.values)
                              DropdownMenuItem(
                                value: mode,
                                child: Text(feedingModeLabel(mode)),
                              ),
                          ],
                          onChanged: c.editable
                              ? (value) {
                                  if (value != null) c.setFeedingMode(value);
                                }
                              : null,
                        ),
                        const SizedBox(height: MomCozySpacing.page),
                        const Text(
                          '月龄由出生日期自动计算。每个宝宝的照护记录会分开保存。',
                          style: TextStyle(
                            fontSize: MomCozyTypography.captionSize,
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                        if (c.validation != null)
                          Padding(
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
                        if (c.failure != null)
                          ProductErrorView(
                            failure: c.failure!,
                            preserveDraft: true,
                            onRetry:
                                c.failure!.kind ==
                                        ProductFailureKind.conflict &&
                                    !c.isNew
                                ? _reload
                                : null,
                          ),
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
                                : '保存宝宝资料',
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
