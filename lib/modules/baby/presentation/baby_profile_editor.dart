import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/choice_field.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
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
        !await confirmDiscard(
          context,
          uncertainSave: c.uncertain,
          theme: momSettingsTheme(Theme.of(context)),
        )) {
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
      theme: momSettingsTheme(Theme.of(context)),
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
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => PopScope<BabyProfile>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Dialog(
          backgroundColor: MomHomeTokens.background,
          surfaceTintColor: Colors.transparent,
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
                final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColoredBox(
                      color: MomHomeTokens.surface,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: keyboard ? 8 : 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.isNew ? '添加宝宝' : '$_profileName 的资料',
                                maxLines: keyboard ? 1 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: MomHomeTokens.text(
                                  20,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: '关闭宝宝资料',
                              onPressed: c.busy ? null : _close,
                              color: MomHomeTokens.rose,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 14,
                          children: [
                            MomSettingsCard(
                              children: [
                                _label('宝宝称呼'),
                                TextField(
                                  controller: _name,
                                  style: MomHomeTokens.text(16),
                                  enabled: c.editable,
                                  maxLength: 120,
                                  onChanged: c.setName,
                                  decoration: const InputDecoration(
                                    hintText: '宝宝称呼',
                                    counterText: '',
                                  ),
                                ),
                                _label('出生日期'),
                                OutlinedButton(
                                  onPressed: c.editable ? _date : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: MomHomeTokens.ink,
                                    backgroundColor: MomHomeTokens.surface,
                                    textStyle: MomHomeTokens.text(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.birthDate?.toString() ?? '尚未登记',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                                if (c.birthDate != null)
                                  TextButton(
                                    onPressed: c.editable
                                        ? () => c.setBirthDate(null)
                                        : null,
                                    child: const Text('清除日期'),
                                  ),
                              ],
                            ),
                            MomSettingsCard(
                              children: [
                                _label('出生记录性别'),
                                Text(
                                  '用于匹配生长参考范围',
                                  style: MomHomeTokens.text(
                                    12,
                                    color: MomHomeTokens.secondary,
                                  ),
                                ),
                                IgnorePointer(
                                  ignoring: !c.editable,
                                  child: ChoiceField(
                                    title: '',
                                    style: ChoiceFieldStyle.momTiles,
                                    options: {
                                      for (final sex in BabySex.values)
                                        sex: sex == BabySex.unspecified
                                            ? '暂不填写'
                                            : babySexLabel(sex),
                                    },
                                    selected: {c.sex},
                                    onChanged: (values) {
                                      if (values.isNotEmpty) {
                                        c.setSex(values.first);
                                      }
                                    },
                                  ),
                                ),
                                _label('目前喂养方式'),
                                DropdownButtonFormField<FeedingMode>(
                                  initialValue: c.feedingMode,
                                  key: ValueKey(c.feedingMode),
                                  isExpanded: true,
                                  itemHeight: null,
                                  style: MomHomeTokens.text(16),
                                  dropdownColor: MomHomeTokens.surface,
                                  decoration: const InputDecoration(),
                                  items: [
                                    for (final mode in FeedingMode.values)
                                      DropdownMenuItem(
                                        value: mode,
                                        child: Text(feedingModeLabel(mode)),
                                      ),
                                  ],
                                  onChanged: c.editable
                                      ? (value) {
                                          if (value != null) {
                                            c.setFeedingMode(value);
                                          }
                                        }
                                      : null,
                                ),
                                Text(
                                  '月龄由出生日期自动计算。每个宝宝的照护记录会分开保存。',
                                  style: MomHomeTokens.text(
                                    13,
                                    color: MomHomeTokens.secondary,
                                  ),
                                ),
                              ],
                            ),
                            if (c.validation != null)
                              Semantics(
                                liveRegion: true,
                                child: MomSettingsCard(
                                  color: MomCozyColors.amberSoft,
                                  border: false,
                                  children: [
                                    Text(
                                      c.validation!,
                                      style: MomHomeTokens.text(
                                        13,
                                        color: MomCozyColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (c.failure != null)
                              ProductErrorView(
                                failure: c.failure!,
                                preserveDraft: true,
                                useMomStyle: true,
                                onRetry:
                                    c.failure!.kind ==
                                            ProductFailureKind.conflict &&
                                        !c.isNew
                                    ? _reload
                                    : null,
                              ),
                            if (c.uncertain)
                              Text(
                                '保存结果还未确认。请重试确认这次保存后再修改内容。',
                                style: MomHomeTokens.text(
                                  13,
                                  color: MomHomeTokens.secondary,
                                ),
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
                          keyboard ? 8 : 16,
                          16,
                          keyboard ? 8 : 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              disabledBackgroundColor:
                                  MomHomeTokens.neutralSurface,
                              disabledForegroundColor: MomHomeTokens.secondary,
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
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _label(String value) =>
      Text(value, style: MomHomeTokens.text(14, weight: FontWeight.w700));
}
