import 'baby_motion.dart';
import 'package:flutter/material.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/date_time_picker.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/zoned_datetime_field.dart';
import '../application/baby_record_editor_controller.dart';
import 'baby_design.dart';
import 'baby_labels.dart';

enum _FeedingType { breast, bottle }

class BabyRecordFields extends StatelessWidget {
  const BabyRecordFields({super.key, required this.controller});
  final BabyRecordEditorController controller;
  Widget _number({
    required String keyName,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required String unit,
    bool decimal = true,
    bool required = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [
      BabyLabel(label, required: required),
      TextFormField(
        key: ValueKey(keyName),
        initialValue: value,
        enabled: controller.editable,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: onChanged,
        style: BabyDesign.text(16),
        decoration: InputDecoration(
          hintText: '—',
          suffixIcon: SizedBox(
            width: 46,
            child: Align(
              alignment: Alignment.centerLeft,
              heightFactor: 1,
              child: Text(
                unit,
                style: BabyDesign.text(14, color: MomHomeTokens.secondary),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  Future<void> _date(BuildContext context) async {
    final c = controller, today = controller.today;
    final earliest = c.baby.birthDate ?? LocalDate(1900, 1, 1);
    final d = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(
        c.recordedOn.year,
        c.recordedOn.month,
        c.recordedOn.day,
      ),
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: '测量日期',
      theme: BabyDesign.theme(
        Theme.of(context),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
    if (d != null && context.mounted) c.setDate(LocalDate.fromDateTime(d));
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final bottle =
        c.bottleSelected ||
        (c.feedingMethod != null &&
            c.feedingMethod != BabyFeedingMethod.breastfeeding);
    final fields = <Widget>[];
    if (c.kind == BabyRecordKind.feeding) {
      fields.addAll([
        const BabyLabel('喂养方式', required: true),
        BabyChoices(
          options: const {_FeedingType.breast: '亲喂', _FeedingType.bottle: '瓶喂'},
          selected: bottle
              ? _FeedingType.bottle
              : c.feedingMethod == BabyFeedingMethod.breastfeeding
              ? _FeedingType.breast
              : null,
          onChanged: (v) => c.selectBottle(v == _FeedingType.bottle),
        ),
        if (bottle)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                const BabyLabel('奶液类型', required: true),
                BabyChoices(
                  options: const {
                    BabyFeedingMethod.expressedMilk: '母乳',
                    BabyFeedingMethod.formula: '配方奶',
                  },
                  selected: c.feedingMethod,
                  onChanged: c.setFeedingMethod,
                ),
              ],
            ),
          ),
        const BabyLabel('发生时间', required: true),
        ZonedDateTimeField(
          label: '',
          valueStyle: BabyDesign.text(16),
          fieldStyle: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          trailing: SizedBox(
            width: 32,
            height: 17,
            child: Align(
              alignment: Alignment.centerLeft,
              child: BabyDesign.asset('Clock', width: 8, height: 8),
            ),
          ),
          showLabel: false,
          bottomSpacing: 0,
          warm: true,
          useMomStyle: true,
          value: c.occurredAt,
          timezone: c.timezone,
          now: c.now,
          enabled: c.editable,
          onChanged: (v) {
            if (v != null) c.setOccurredAt(v);
          },
        ),
        if (c.feedingMethod == BabyFeedingMethod.breastfeeding) ...[
          const BabyLabel('亲喂侧别'),
          BabyChoices(
            options: const {FeedingSide.left: '左侧', FeedingSide.right: '右侧'},
            selected: c.feedingSide,
            onChanged: c.setSide,
          ),
          _number(
            keyName: 'nursing-duration',
            label: '亲喂时长',
            value: c.duration,
            onChanged: c.setDuration,
            unit: '分钟',
            decimal: false,
          ),
        ] else if (bottle)
          _number(
            keyName: 'feeding-volume',
            label: '实际瓶喂量',
            value: c.volume,
            onChanged: c.setVolume,
            unit: 'ml',
          ),
      ]);
    } else if (c.isDaily) {
      switch (c.dailyTab) {
        case BabyDailyTab.mental:
          fields.addAll([
            const BabyLabel('吃奶后精神状态', required: true),
            BabyChoices(
              options: babyMentalLabels,
              selected: c.mentalState,
              onChanged: c.setMentalState,
            ),
          ]);
        case BabyDailyTab.wet:
          fields.add(
            _number(
              keyName: 'wet-count',
              label: '今日湿尿布数',
              value: c.wetCount,
              onChanged: c.setWetCount,
              unit: '片',
              decimal: false,
              required: true,
            ),
          );
        case BabyDailyTab.stool:
          fields.addAll([
            _number(
              keyName: 'stool-count',
              label: '今日便便次数',
              value: c.stoolCount,
              onChanged: c.setStoolCount,
              unit: '次',
              decimal: false,
              required: true,
            ),
            const BabyLabel('便便颜色'),
            BabyChoices(
              options: stoolColorLabels,
              selected: c.stoolColor,
              onChanged: c.setStoolColor,
              columns: 4,
              icon: (v) => Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (v) {
                    StoolColor.yellow => const Color(0xffe8be22),
                    StoolColor.yellowBrown => const Color(0xffbb8836),
                    StoolColor.green => const Color(0xff7f9654),
                    StoolColor.brown => const Color(0xff7c5538),
                    StoolColor.black => const Color(0xff2f2b28),
                    StoolColor.red => const Color(0xffae4745),
                    StoolColor.pale => const Color(0xffded9c9),
                    StoolColor.unsure => const Color(0xffede8e2),
                  },
                ),
              ),
            ),
            const BabyLabel('便便性状'),
            BabyChoices(
              options: stoolConsistencyLabels,
              selected: c.stoolConsistency,
              onChanged: c.setStoolConsistency,
              columns: 3,
            ),
          ]);
      }
    } else if (c.kind == BabyRecordKind.growth) {
      fields.addAll([
        const BabyLabel('测量项目'),
        BabyChoices(
          options: {
            for (final m in GrowthMetric.values) m: growthMetricLabel(m),
          },
          selected: c.growthMetric,
          onChanged: c.selectMetric,
          columns: 3,
        ),
        _number(
          keyName: 'growth-${c.growthMetric.name}',
          label: '${growthMetricLabel(c.growthMetric)}数值',
          value: c.growthValues[c.growthMetric] ?? '',
          onChanged: (v) => c.setGrowthValue(c.growthMetric, v),
          unit: c.growthMetric == GrowthMetric.weight ? 'kg' : 'cm',
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        MomSettingsCard(borderInside: true, children: fields),
        if (c.kind == BabyRecordKind.growth)
          MomSettingsCard(
            borderInside: true,
            children: [
              const BabyLabel('测量日期'),
              BabyPressFeedback(
                child: OutlinedButton(
                  onPressed: c.editable ? () => _date(context) : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: MomHomeTokens.surface,
                    foregroundColor: MomHomeTokens.ink,
                    textStyle: BabyDesign.text(16),
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.recordedOn.toString())),
                      SizedBox(
                        width: 32,
                        height: 17,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: BabyDesign.asset(
                            'Calendar',
                            width: 10,
                            height: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
