import 'package:flutter/material.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/choice_field.dart';
import '../../../shared/widgets/zoned_datetime_field.dart';
import '../application/baby_record_editor_controller.dart';
import 'baby_labels.dart';

class BabyRecordFields extends StatelessWidget {
  const BabyRecordFields({super.key, required this.controller});
  final BabyRecordEditorController controller;
  Future<void> _date(BuildContext context) async {
    final c = controller, today = controller.today;
    final birth = c.baby.birthDate;
    final earliest = birth != null && birth.compareTo(today) <= 0
        ? birth
        : LocalDate(1900, 1, 1);
    final initial = c.recordedOn.compareTo(today) > 0
        ? today
        : c.recordedOn.compareTo(earliest) < 0
        ? earliest
        : c.recordedOn;
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: c.kind == BabyRecordKind.growth ? '测量日期' : '观察日期',
    );
    if (value != null && context.mounted) {
      c.setDate(LocalDate.fromDateTime(value));
    }
  }

  Widget _number({
    required String keyName,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool decimal = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: MomCozySpacing.page),
    child: TextFormField(
      key: ValueKey(keyName),
      initialValue: value,
      enabled: controller.editable,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          ignoring: !c.editable,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.kind == BabyRecordKind.feeding) ...[
                ChoiceField(
                  title: '喂养方式',
                  options: babyFeedingLabels,
                  selected: {if (c.feedingMethod != null) c.feedingMethod!},
                  onChanged: (value) => c.setFeedingMethod(value.firstOrNull),
                ),
                ZonedDateTimeField(
                  label: '发生时间',
                  value: c.occurredAt,
                  timezone: c.timezone,
                  now: c.now,
                  enabled: c.editable,
                  onChanged: (value) {
                    if (value != null) c.setOccurredAt(value);
                  },
                ),
                if (c.feedingMethod == BabyFeedingMethod.breastfeeding) ...[
                  ChoiceField(
                    title: '亲喂侧别',
                    options: feedingSideLabels,
                    selected: {if (c.feedingSide != null) c.feedingSide!},
                    onChanged: (value) => c.setSide(value.firstOrNull),
                  ),
                  _number(
                    keyName: 'nursing-duration',
                    label: '亲喂时长（分钟，可不填）',
                    value: c.duration,
                    onChanged: c.setDuration,
                    decimal: false,
                  ),
                ] else if (c.feedingMethod != null)
                  _number(
                    keyName: 'feeding-volume',
                    label: '本次瓶喂量（ml，可不填）',
                    value: c.volume,
                    onChanged: c.setVolume,
                  ),
                const Text(
                  '可以先记时间和方式。没有测量的数值请留空。',
                  style: TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
              if (c.kind == BabyRecordKind.diaper) ...[
                ChoiceField(
                  title: '这次换到的尿布',
                  options: diaperKindLabels,
                  selected: {if (c.diaperKind != null) c.diaperKind!},
                  onChanged: (value) => c.setDiaperKind(value.firstOrNull),
                ),
                ZonedDateTimeField(
                  label: '发生时间',
                  value: c.occurredAt,
                  timezone: c.timezone,
                  now: c.now,
                  enabled: c.editable,
                  onChanged: (value) {
                    if (value != null) c.setOccurredAt(value);
                  },
                ),
                if (c.diaperKind != null && c.diaperKind != DiaperKind.wet) ...[
                  ChoiceField(
                    title: '便便颜色（可不填）',
                    options: stoolColorLabels,
                    selected: {if (c.stoolColor != null) c.stoolColor!},
                    onChanged: (value) => c.setStoolColor(value.firstOrNull),
                  ),
                  ChoiceField(
                    title: '便便质地（可不填）',
                    options: stoolConsistencyLabels,
                    selected: {
                      if (c.stoolConsistency != null) c.stoolConsistency!,
                    },
                    onChanged: (value) =>
                        c.setStoolConsistency(value.firstOrNull),
                  ),
                  ChoiceField(
                    title: '看到的情况（可多选）',
                    options: stoolSignLabels,
                    selected: c.stoolSigns,
                    multiple: true,
                    onChanged: c.setStoolSigns,
                  ),
                ],
              ],
              if (c.kind == BabyRecordKind.sleep) ...[
                if (c.hasActiveSleep)
                  Container(
                    padding: const EdgeInsets.all(MomCozySpacing.page),
                    decoration: BoxDecoration(
                      color: MomCozyColors.violetSoft,
                      borderRadius: BorderRadius.circular(MomCozyRadii.control),
                    ),
                    child: Text(
                      '${c.baby.name} 正在睡\n已记录 ${babyDuration(c.now().difference((c.target as BabySleepRecord).occurredAt))}',
                    ),
                  ),
                ZonedDateTimeField(
                  label: '入睡时间',
                  value: c.sleepStartedAt,
                  timezone: c.timezone,
                  now: c.now,
                  enabled: c.editable,
                  onChanged: (value) {
                    if (value != null) c.setSleepStart(value);
                  },
                ),
                ZonedDateTimeField(
                  label: '醒来时间（可不填）',
                  value: c.sleepEndedAt,
                  timezone: c.timezone,
                  now: c.now,
                  enabled: c.editable,
                  clearable: true,
                  onChanged: c.setSleepEnd,
                ),
                const Text(
                  '还在睡时，醒来时间留空即可。跨午夜的睡眠会按每天实际重叠的时长统计。',
                  style: TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
              if (c.kind == BabyRecordKind.growth) ...[
                Wrap(
                  spacing: MomCozySpacing.compact,
                  runSpacing: MomCozySpacing.xs,
                  children: [
                    for (final metric in GrowthMetric.values)
                      ChoiceChip(
                        label: Text(growthMetricLabel(metric)),
                        selected: c.growthMetric == metric,
                        avatar:
                            c.growthValues[metric]?.trim().isNotEmpty == true
                            ? const Icon(Icons.check, size: 14)
                            : null,
                        onSelected:
                            c.editing &&
                                (c.initial as BabyGrowthRecord).metric != metric
                            ? null
                            : (_) => c.selectMetric(metric),
                      ),
                  ],
                ),
                const SizedBox(height: MomCozySpacing.card),
                _number(
                  keyName: 'growth-${c.growthMetric.name}',
                  label:
                      '${growthMetricLabel(c.growthMetric)}（${c.growthMetric == GrowthMetric.weight ? 'kg' : 'cm'}）',
                  value: c.growthValues[c.growthMetric] ?? '',
                  onChanged: (value) => c.setGrowthValue(c.growthMetric, value),
                ),
                if (!c.editing)
                  const Text(
                    '可以切换填写多项数值，已填写的测量会一起保存。',
                    style: TextStyle(
                      fontSize: MomCozyTypography.captionSize,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
              ],
              if (c.kind == BabyRecordKind.development) ...[
                const Text('记录实际看到的行为，拿不准时可以选择“不确定”。'),
                const SizedBox(height: MomCozySpacing.page),
                for (final item in babyDevelopmentItems.entries)
                  if (!c.editing ||
                      (c.initial as BabyDevelopmentRecord).itemId == item.key)
                    ChoiceField(
                      title: item.value,
                      options: developmentStatusLabels,
                      selected: {
                        if (c.development[item.key] != null)
                          c.development[item.key]!,
                      },
                      onChanged: (value) =>
                          c.setDevelopment(item.key, value.firstOrNull),
                    ),
                const Text(
                  '这些记录用于观察变化，不代表发育评估结果。',
                  style: TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if ([
          BabyRecordKind.growth,
          BabyRecordKind.development,
        ].contains(c.kind))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c.kind == BabyRecordKind.growth ? '测量日期' : '观察日期'),
            subtitle: Text(c.recordedOn.toString()),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: c.editable ? () => _date(context) : null,
          )
        else ...[
          const SizedBox(height: MomCozySpacing.card),
          TextFormField(
            key: ValueKey('note-${c.kind.name}'),
            initialValue: c.note,
            enabled: c.editable,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            onChanged: c.setNote,
            decoration: const InputDecoration(labelText: '备注（可不填）'),
          ),
        ],
      ],
    );
  }
}
