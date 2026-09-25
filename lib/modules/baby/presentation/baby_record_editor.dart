import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../application/baby_record_editor_controller.dart';
import 'baby_design.dart';
import 'baby_motion.dart';
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
    growthMetric: growthMetric,
  );
  controller.dailyTab = diaperKind == DiaperKind.wet
      ? BabyDailyTab.wet
      : diaperKind == DiaperKind.dirty
      ? BabyDailyTab.stool
      : BabyDailyTab.mental;
  try {
    final result = await showBabySheet<List<BabyRecord>>(
      context,
      BabyRecordEditor(controller: controller),
    );
    // A dismissed sheet can still have a successfully committed snapshot.
    await controller.settled;
    return result ?? controller.lastSaved;
  } finally {
    // Dismissing a sheet does not cancel the already submitted snapshot.
    await controller.settled;
    controller.dispose();
  }
}

class BabyRecordEditor extends StatelessWidget {
  const BabyRecordEditor({super.key, required this.controller});
  final BabyRecordEditorController controller;
  @override
  Widget build(BuildContext context) => Theme(
    data: BabyDesign.theme(
      Theme.of(context),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    ),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        final title = c.kind == BabyRecordKind.feeding
            ? 'Log feeding'
            : c.kind == BabyRecordKind.growth
            ? 'Growth & development'
            : switch (c.dailyTab) {
                BabyDailyTab.mental => 'Log mood after feeding',
                BabyDailyTab.wet => 'Log wet diapers',
                BabyDailyTab.stool => 'Log dirty diapers',
              };
        return BabySheetBody(
          title: title,
          bodyTop: c.isDaily && c.dailyTab == BabyDailyTab.stool ? 14 : 16,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              if (c.isDaily)
                BabyChoices(
                  options: const {
                    BabyDailyTab.mental: 'Mood',
                    BabyDailyTab.wet: 'Wet diapers',
                    BabyDailyTab.stool: 'Dirty diapers',
                  },
                  selected: c.dailyTab,
                  onChanged: c.selectDailyTab,
                  columns: 3,
                  enabled: c.editable,
                ),
              AnimatedOpacity(
                duration: BabyMotion.duration(context, BabyMotion.feedback),
                opacity: c.busy ? .55 : 1,
                child: IgnorePointer(
                  ignoring: !c.editable,
                  child: BabyContentTransition(
                    selection: c.isDaily
                        ? c.dailyTab
                        : c.kind == BabyRecordKind.growth
                        ? c.growthMetric
                        : c.bottleSelected
                        ? 'bottle'
                        : c.feedingMethod?.name ?? 'empty',
                    child: BabyRecordFields(controller: c),
                  ),
                ),
              ),
              if (c.failure != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6eddc),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Could not save. Please try again.',
                      style: BabyDesign.text(13),
                    ),
                  ),
                ),
            ],
          ),
          footer: BabyPressFeedback(
            child: FilledButton(
              key: const ValueKey('baby-save'),
              style: c.busy
                  ? FilledButton.styleFrom(
                      disabledBackgroundColor: const Color(0xfff2ebe5),
                      disabledForegroundColor: const Color(0xff776e69),
                    )
                  : null,
              onPressed: c.canSave
                  ? () async {
                      FocusScope.of(context).unfocus();
                      final saved = await c.save();
                      if (context.mounted && saved != null) {
                        Navigator.pop(context, saved);
                      }
                    }
                  : null,
              child: BabyAnimatedLabel(c.busy ? 'Saving…' : 'Save'),
            ),
          ),
        );
      },
    ),
  );
}
