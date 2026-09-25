import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
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
      MaterialPageRoute(builder: (_) => BabyProfileEditor(controller: c)),
    );
    return c.hasSaved ? c.savedProfile : null;
  } finally {
    c.dispose();
  }
}

class BabyProfileEditor extends StatefulWidget {
  const BabyProfileEditor({super.key, required this.controller});
  final BabyProfileController controller;
  @override
  State<BabyProfileEditor> createState() => _BabyProfileEditorState();
}

class _BabyProfileEditorState extends State<BabyProfileEditor> {
  late final name = TextEditingController(text: widget.controller.name);
  bool saved = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: BabyDesign.theme(
      Theme.of(context),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
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
                  tooltip: 'Back',
                  onPressed: c.busy ? null : () => Navigator.pop(context),
                  icon: BabyDesign.asset('Back', width: 20, height: 20),
                  color: MomHomeTokens.rose,
                ),
              ),
              titleSpacing: 0,
              title: SizedBox(
                width: MediaQuery.sizeOf(context).width - 112,
                child: Text(
                  savedName.isEmpty ? 'Add a baby' : 'Baby profile',
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
                              const BabyLabel('Baby\'s name', required: true),
                              TextField(
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
                                  hintText: 'What do you call your baby?',
                                  counterText: '',
                                ),
                              ),
                              const BabyLabel('Date of birth'),
                              Text(
                                c.birthDate?.toString() ?? '—',
                                style: BabyDesign.text(16),
                              ),
                              Text(
                                'Same as the delivery date in your profile',
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
                              const BabyLabel(
                                'Sex recorded at birth',
                                required: true,
                              ),
                              Text(
                                'Used to show the appropriate growth reference range',
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
                                  options: const {
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
                          if (c.failure != null)
                            Text(
                              'Could not save. Please try again.',
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
                                  if (mounted && result != null) {
                                    setState(() => saved = true);
                                  }
                                }
                              : null,
                          child: BabyAnimatedLabel(
                            c.busy
                                ? 'Saving…'
                                : saved && !c.dirty
                                ? 'Saved'
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
