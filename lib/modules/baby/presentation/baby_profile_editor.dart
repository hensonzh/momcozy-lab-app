import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/date_time_picker.dart';
import '../application/baby_profile_controller.dart';
import 'baby_design.dart';
import 'baby_motion.dart';

Future<BabyProfile?> showBabyProfileEditor(
  BuildContext context, {
  required BabyProfileRepository repository,
  required String timezone,
  required DateTime Function() now,
  BabyProfile? profile,
  LocalDate? deliveryDate,
  bool closeOnSave = false,
  bool chatFirstExperience = false,
}) async {
  final c = BabyProfileController(
    repository: repository,
    timezone: timezone,
    now: now,
    initial: profile,
    deliveryDate: deliveryDate,
  );
  try {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => BabyProfileEditor(
          controller: c,
          closeOnSave: closeOnSave,
          chatFirstExperience: chatFirstExperience,
        ),
      ),
    );
    return c.hasSaved ? c.savedProfile : null;
  } finally {
    c.dispose();
  }
}

class BabyProfileEditor extends StatefulWidget {
  const BabyProfileEditor({
    super.key,
    required this.controller,
    this.closeOnSave = false,
    this.chatFirstExperience = false,
  });
  final BabyProfileController controller;
  final bool closeOnSave;
  final bool chatFirstExperience;
  @override
  State<BabyProfileEditor> createState() => _BabyProfileEditorState();
}

class _BabyProfileEditorState extends State<BabyProfileEditor> {
  late final name = TextEditingController(text: widget.controller.name);
  bool saved = false;

  Future<void> _chooseBirthDate() async {
    final c = widget.controller;
    final today = c.today;
    final birth = c.birthDate;
    final initial =
        birth != null &&
            birth.compareTo(LocalDate(1900, 1, 1)) >= 0 &&
            birth.compareTo(today) <= 0
        ? birth
        : today;
    final selected = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: widget.chatFirstExperience ? '宝宝出生日期' : 'Date of birth',
      locale: widget.chatFirstExperience ? const Locale('zh', 'CN') : null,
      theme: BabyDesign.theme(Theme.of(context)),
    );
    if (mounted && selected != null) {
      c.setBirthDate(LocalDate.fromDateTime(selected));
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: BabyDesign.theme(
      Theme.of(context),
      reduceMotion: MomCozyMotion.isReduced(context),
    ),
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final savedName = c.savedProfile?.name ?? '';
        return PopScope(
          canPop: !c.busy,
          child: Scaffold(
            backgroundColor: MomHomeTokens.background,
            appBar: AppBar(
              backgroundColor: MomHomeTokens.background,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? 108
                  : 60,
              leading: BabyPressFeedback(
                child: IconButton(
                  tooltip: widget.chatFirstExperience ? '返回' : 'Back',
                  onPressed: c.busy ? null : () => Navigator.pop(context),
                  icon: BabyDesign.asset('Back', width: 20, height: 20),
                  color: MomHomeTokens.rose,
                ),
              ),
              titleSpacing: 0,
              title: SizedBox(
                width: MediaQuery.sizeOf(context).width - 112,
                child: Text(
                  savedName.isEmpty
                      ? widget.chatFirstExperience
                            ? '添加宝宝'
                            : 'Add a baby'
                      : widget.chatFirstExperience
                      ? '宝宝资料'
                      : 'Baby profile',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: BabyDesign.text(20, weight: FontWeight.w600),
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 29.5,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 14,
                        children: [
                          MomSettingsCard(
                            borderInside: true,
                            children: [
                              BabyLabel(
                                widget.chatFirstExperience
                                    ? '宝宝称呼'
                                    : 'Baby\'s name',
                                required: true,
                              ),
                              Semantics(
                                container: true,
                                label: widget.chatFirstExperience
                                    ? '宝宝称呼'
                                    : 'Baby\'s name',
                                child: TextField(
                                  controller: name,
                                  enabled: c.editable,
                                  maxLength: 120,
                                  onChanged: c.setName,
                                  style: BabyDesign.text(
                                    16,
                                    color: c.busy
                                        ? const Color(0xff99918c)
                                        : MomHomeTokens.ink,
                                  ),
                                  decoration: InputDecoration(
                                    fillColor: c.busy
                                        ? const Color(0xfff2edeb)
                                        : MomHomeTokens.surface,
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: MomHomeTokens.border,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11.2,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: MomHomeTokens.border,
                                      ),
                                    ),
                                    hintText: widget.chatFirstExperience
                                        ? '如何称呼宝宝？'
                                        : 'What do you call your baby?',
                                    counterText: '',
                                  ),
                                ),
                              ),
                              BabyLabel(
                                widget.chatFirstExperience
                                    ? '出生日期'
                                    : 'Date of birth',
                                required: true,
                              ),
                              if (c.deliveryDate == null)
                                OutlinedButton(
                                  onPressed: c.editable
                                      ? _chooseBirthDate
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: MomHomeTokens.surface,
                                    alignment: Alignment.centerLeft,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  child: Text(
                                    c.birthDate?.toString() ??
                                        (widget.chatFirstExperience
                                            ? '选择出生日期'
                                            : 'Choose date of birth'),
                                  ),
                                )
                              else
                                Text(
                                  c.birthDate.toString(),
                                  style: BabyDesign.text(16),
                                ),
                              if (c.deliveryDate != null || c.birthDate == null)
                                Text(
                                  c.deliveryDate != null
                                      ? widget.chatFirstExperience
                                            ? '与妈妈资料中的分娩日期相同'
                                            : 'Same as the delivery date in your profile'
                                      : widget.chatFirstExperience
                                      ? '请选择宝宝的出生日期'
                                      : 'Choose a date to complete your baby’s profile',
                                  style: BabyDesign.text(
                                    13,
                                    color: MomHomeTokens.secondary,
                                  ),
                                ),
                            ],
                          ),
                          MomSettingsCard(
                            borderInside: true,
                            children: [
                              BabyLabel(
                                widget.chatFirstExperience
                                    ? '出生时登记性别'
                                    : 'Sex recorded at birth',
                                required: true,
                              ),
                              Text(
                                widget.chatFirstExperience
                                    ? '用于匹配相应的生长参考范围'
                                    : 'Used to show the appropriate growth reference range',
                                style: BabyDesign.text(
                                  13,
                                  color: MomHomeTokens.secondary,
                                ),
                              ),
                              AnimatedOpacity(
                                duration: BabyMotion.duration(
                                  context,
                                  BabyMotion.feedback,
                                ),
                                opacity: c.busy ? .5 : 1,
                                child: BabyChoices(
                                  height: 44,
                                  radius: 16,
                                  options: widget.chatFirstExperience
                                      ? const {
                                          BabySex.female: '女孩',
                                          BabySex.male: '男孩',
                                        }
                                      : const {
                                          BabySex.female: 'Girl',
                                          BabySex.male: 'Boy',
                                        },
                                  selected: c.sex,
                                  enabled: c.editable,
                                  onChanged: c.setSex,
                                ),
                              ),
                            ],
                          ),
                          if (c.validation != null)
                            Text(
                              widget.chatFirstExperience
                                  ? switch (c.validation!) {
                                      "Enter your baby's name." => '请输入宝宝称呼。',
                                      'The name cannot exceed 120 characters.' =>
                                        '宝宝称呼不能超过 120 个字符。',
                                      'The date of birth cannot be in the future.' =>
                                        '出生日期不能晚于今天。',
                                      _ => '请检查宝宝资料后重试。',
                                    }
                                  : c.validation!,
                              style: BabyDesign.text(13),
                            ),
                          if (c.failure != null)
                            Text(
                              widget.chatFirstExperience
                                  ? '暂时无法保存，请检查网络后重试。'
                                  : 'Could not save. Please try again.',
                              style: BabyDesign.text(13),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: BabyPressFeedback(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size.fromHeight(44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: c.canSave
                              ? () async {
                                  FocusScope.of(context).unfocus();
                                  final result = await c.save();
                                  if (mounted &&
                                      context.mounted &&
                                      result != null) {
                                    if (widget.closeOnSave) {
                                      Navigator.pop(context);
                                    } else {
                                      setState(() => saved = true);
                                    }
                                  }
                                }
                              : null,
                          child: BabyAnimatedLabel(
                            c.busy
                                ? widget.chatFirstExperience
                                      ? '保存中…'
                                      : 'Saving…'
                                : saved && !c.dirty
                                ? widget.chatFirstExperience
                                      ? '已保存'
                                      : 'Saved'
                                : widget.chatFirstExperience
                                ? '保存宝宝资料'
                                : 'Save baby profile',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
