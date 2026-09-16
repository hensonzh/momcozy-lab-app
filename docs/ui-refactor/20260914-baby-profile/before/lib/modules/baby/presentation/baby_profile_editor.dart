import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/choice_field.dart';
import '../../../shared/widgets/warm_editor_header.dart';
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
      animationStyle: MomCozyMotion.animationStyle(context),
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
  late final _profileName = widget.controller.name;
  late final _name = TextEditingController(text: widget.controller.name);
  bool _allowPop = false, _closing = false;
  final _scroll = ScrollController();
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
    final date = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(selected.year, selected.month, selected.day),
      currentDate: DateTime(c.today.year, c.today.month, c.today.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(c.today.year, c.today.month, c.today.day),
      helpText: '宝宝出生日期',
    );
    if (date != null && mounted) c.setBirthDate(LocalDate.fromDateTime(date));
  }

  Future<void> _save() async {
    final saved = await widget.controller.save();
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

  Future<void> _reload() async {
    if (await widget.controller.reload() && mounted) {
      _name.text = widget.controller.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<BabyProfile>(
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
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 760),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (_, _) {
            final c = widget.controller;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WarmEditorHeader(
                  title: c.isNew ? '添加宝宝' : '$_profileName 的资料',
                  maxTitleLines: MediaQuery.viewInsetsOf(context).bottom > 0
                      ? 1
                      : 3,
                  closeLabel: '关闭宝宝资料',
                  onClose: c.busy ? null : _close,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '宝宝称呼',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: MomCozyColors.diaryInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _name,
                          style: const TextStyle(
                            fontSize: 16,
                            color: MomCozyColors.diaryInk,
                          ),
                          enabled: c.editable,
                          maxLength: 120,
                          onChanged: c.setName,
                          decoration: const InputDecoration(
                            hintText: '宝宝称呼',
                            filled: true,
                            fillColor: MomCozyColors.warmFormField,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: MomCozySpacing.page),
                        const Text(
                          '出生日期',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: MomCozyColors.diaryInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: c.editable ? _date : null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            backgroundColor: MomCozyColors.warmFormField,
                            foregroundColor: MomCozyColors.diaryInk,
                            side: const BorderSide(
                              color: MomCozyColors.warmFormBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(c.birthDate?.toString() ?? '尚未登记'),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: MomCozyColors.diaryInk,
                          ),
                        ),
                        const Text(
                          '用于匹配生长参考范围',
                          style: TextStyle(
                            color: MomCozyColors.mutedForeground,
                            fontSize: 11,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: MomCozySpacing.compact),
                        IgnorePointer(
                          ignoring: !c.editable,
                          child: ChoiceField(
                            title: '',
                            style: ChoiceFieldStyle.warmTiles,
                            options: {
                              for (final sex in BabySex.values)
                                sex: sex == BabySex.unspecified
                                    ? '暂不填写'
                                    : babySexLabel(sex),
                            },
                            selected: {c.sex},
                            onChanged: (values) {
                              if (values.isNotEmpty) c.setSex(values.first);
                            },
                          ),
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
                            fontSize: 11,
                            height: 1.7,
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
                        style: FilledButton.styleFrom(
                          backgroundColor: MomCozyColors.diaryHeader,
                          foregroundColor: MomCozyColors.diaryBright,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
              ],
            );
          },
        ),
      ),
    ),
  );
}
