import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/choice_field.dart';
import '../../../shared/zoned_time.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../../../shared/widgets/zoned_datetime_field.dart';
import '../application/baby_record_editor_controller.dart';
import 'baby_labels.dart';

class BabyRecordFields extends StatefulWidget {
  const BabyRecordFields({super.key, required this.controller});
  final BabyRecordEditorController controller;
  @override
  State<BabyRecordFields> createState() => _BabyRecordFieldsState();
}

class _BabyRecordFieldsState extends State<BabyRecordFields> {
  bool _adjustActiveSleep = false;
  BabyRecordEditorController get controller => widget.controller;
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
    final value = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      currentDate: DateTime(today.year, today.month, today.day),
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: c.kind == BabyRecordKind.growth ? '测量日期' : '观察日期',
      theme: momSettingsTheme(Theme.of(context)),
    );
    if (value != null && context.mounted) {
      c.setDate(LocalDate.fromDateTime(value));
    }
  }

  Widget _choice<T extends Enum>({
    required String title,
    required Map<T, String> options,
    required Set<T> selected,
    required ValueChanged<Set<T>> onChanged,
    ChoiceFieldStyle style = ChoiceFieldStyle.momTiles,
    int columns = 3,
    bool multiple = false,
    Widget Function(T)? optionIcon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: ChoiceField<T>(
      title: title,
      options: options,
      selected: selected,
      onChanged: onChanged,
      style: style,
      columns: columns,
      multiple: multiple,
      optionIcon: optionIcon,
    ),
  );

  Widget _number({
    required String keyName,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool decimal = true,
    String? unit,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: MomCozySpacing.page),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w700,
            color: MomHomeTokens.ink,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey(keyName),
          initialValue: value,
          enabled: controller.editable,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, color: MomHomeTokens.ink),
          decoration: InputDecoration(
            hintText: '—',
            suffixIcon: unit == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MomHomeTokens.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
            filled: true,
            fillColor: MomHomeTokens.surface,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MomHomeTokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MomHomeTokens.teal),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MomSettingsCard(
          children: [
            IgnorePointer(
              ignoring: !c.editable,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.kind == BabyRecordKind.feeding) ...[
                    _choice(
                      style: ChoiceFieldStyle.momTiles,
                      title: '喂养方式',
                      options: babyFeedingLabels,
                      selected: {if (c.feedingMethod != null) c.feedingMethod!},
                      onChanged: (value) =>
                          c.setFeedingMethod(value.firstOrNull),
                    ),
                    ZonedDateTimeField(
                      warm: true,
                      useMomStyle: true,
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
                      _choice(
                        style: ChoiceFieldStyle.momTiles,
                        title: '亲喂侧别',
                        options: feedingSideLabels,
                        selected: {if (c.feedingSide != null) c.feedingSide!},
                        onChanged: (value) => c.setSide(value.firstOrNull),
                      ),
                      _number(
                        keyName: 'nursing-duration',
                        label: '亲喂时长（可不填）',
                        unit: '分钟',
                        value: c.duration,
                        onChanged: c.setDuration,
                        decimal: false,
                      ),
                    ] else if (c.feedingMethod != null)
                      _number(
                        keyName: 'feeding-volume',
                        label: '实际瓶喂量（可不填）',
                        unit: 'ml',
                        value: c.volume,
                        onChanged: c.setVolume,
                      ),
                  ],
                  if (c.kind == BabyRecordKind.diaper) ...[
                    _choice(
                      style: ChoiceFieldStyle.momTiles,
                      title: '这次换到的尿布',
                      options: diaperKindLabels,
                      selected: {if (c.diaperKind != null) c.diaperKind!},
                      onChanged: (value) => c.setDiaperKind(value.firstOrNull),
                    ),
                    ZonedDateTimeField(
                      warm: true,
                      useMomStyle: true,
                      label: '发生时间',
                      value: c.occurredAt,
                      timezone: c.timezone,
                      now: c.now,
                      enabled: c.editable,
                      onChanged: (value) {
                        if (value != null) c.setOccurredAt(value);
                      },
                    ),
                    if (c.diaperKind != null &&
                        c.diaperKind != DiaperKind.wet) ...[
                      _choice(
                        style: ChoiceFieldStyle.momTiles,
                        title: '便便颜色（可不填）',
                        columns: 4,
                        optionIcon: (color) => Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: .15),
                            ),
                            color: switch (color) {
                              StoolColor.yellow => const Color(0xffe6bf30),
                              StoolColor.yellowBrown => const Color(0xffb9893f),
                              StoolColor.green => const Color(0xff7b9255),
                              StoolColor.brown => const Color(0xff795539),
                              StoolColor.black => const Color(0xff302b28),
                              StoolColor.red => const Color(0xffa74946),
                              StoolColor.pale => const Color(0xffdfd9c9),
                              StoolColor.unsure => const Color(0xffeee9e3),
                            },
                          ),
                          child: color == StoolColor.unsure
                              ? const Icon(
                                  Icons.question_mark,
                                  size: 12,
                                  color: MomHomeTokens.secondary,
                                )
                              : null,
                        ),
                        options: stoolColorLabels,
                        selected: {if (c.stoolColor != null) c.stoolColor!},
                        onChanged: (value) =>
                            c.setStoolColor(value.firstOrNull),
                      ),
                      _choice(
                        style: ChoiceFieldStyle.momTiles,
                        title: '便便质地（可不填）',
                        columns: 2,
                        options: stoolConsistencyLabels,
                        selected: {
                          if (c.stoolConsistency != null) c.stoolConsistency!,
                        },
                        onChanged: (value) =>
                            c.setStoolConsistency(value.firstOrNull),
                      ),
                      _choice(
                        style: ChoiceFieldStyle.momTiles,
                        title: '看到的情况（可多选）',
                        columns: 2,
                        options: stoolSignLabels,
                        selected: c.stoolSigns,
                        multiple: true,
                        onChanged: c.setStoolSigns,
                      ),
                    ],
                  ],
                  if (c.kind == BabyRecordKind.sleep) ...[
                    if (!c.hasActiveSleep) ...[
                      const Text(
                        '记录一段明确的起止时间',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: MomHomeTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '正在睡可以只填入睡时间；已经醒来时，再补上醒来时间。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (c.hasActiveSleep && !c.editing) ...[
                      Container(
                        constraints: const BoxConstraints(minHeight: 260),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: MomHomeTokens.mint,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: MomCozyLineIcon(
                                  MomCozyLineGlyph.moon,
                                  size: 25,
                                  color: MomHomeTokens.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              '${c.baby.name} 正在睡',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                                color: MomHomeTokens.ink,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '从 ${zonedClock((c.target as BabySleepRecord).occurredAt, c.timezone)} 开始，现在约 ${babyDuration(c.now().difference((c.target as BabySleepRecord).occurredAt))}。',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.7,
                                color: MomHomeTokens.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: c.editable
                            ? () => setState(
                                () => _adjustActiveSleep = !_adjustActiveSleep,
                              )
                            : null,
                        child: Text(
                          _adjustActiveSleep ? '收起时间和备注' : '调整时间和备注',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MomHomeTokens.secondary,
                          ),
                        ),
                      ),
                    ],
                    if (!c.hasActiveSleep ||
                        c.editing ||
                        _adjustActiveSleep) ...[
                      ZonedDateTimeField(
                        warm: true,
                        useMomStyle: true,
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
                        warm: true,
                        useMomStyle: true,
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
                          fontSize: 12,
                          height: 1.7,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                    ],
                  ],
                  if (c.kind == BabyRecordKind.growth) ...[
                    _choice(
                      style: ChoiceFieldStyle.momTiles,
                      title: '测量项目',
                      options: {
                        for (final metric in GrowthMetric.values)
                          if (!c.editing ||
                              (c.initial as BabyGrowthRecord).metric == metric)
                            metric:
                                '${growthMetricLabel(metric)}${c.growthValues[metric]?.trim().isNotEmpty == true && c.growthMetric != metric ? ' ✓' : ''}',
                      },
                      selected: {c.growthMetric},
                      onChanged: (values) {
                        if (values.isNotEmpty) c.selectMetric(values.first);
                      },
                    ),
                    _number(
                      keyName: 'growth-${c.growthMetric.name}',
                      label: '${growthMetricLabel(c.growthMetric)}数值',
                      unit: c.growthMetric == GrowthMetric.weight ? 'kg' : 'cm',
                      value: c.growthValues[c.growthMetric] ?? '',
                      onChanged: (value) =>
                          c.setGrowthValue(c.growthMetric, value),
                    ),
                    if (!c.editing)
                      const Text(
                        '可以切换填写多项数值，已填写的测量会一起保存。',
                        style: TextStyle(
                          fontSize: MomCozyTypography.captionSize,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                  ],
                  if (c.kind == BabyRecordKind.development) ...[
                    const Text('记录实际看到的行为，拿不准时可以选择“不确定”。'),
                    const SizedBox(height: MomCozySpacing.page),
                    for (final item in babyDevelopmentItems.entries)
                      if (!c.editing ||
                          (c.initial as BabyDevelopmentRecord).itemId ==
                              item.key)
                        _choice(
                          style: ChoiceFieldStyle.momTiles,
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
                        fontSize: 12,
                        height: 1.7,
                        color: MomHomeTokens.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if ([
          BabyRecordKind.growth,
          BabyRecordKind.development,
        ].contains(c.kind))
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: MomSettingsCard(
              children: [
                Text(
                  c.kind == BabyRecordKind.growth ? '测量日期' : '观察日期',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                    color: MomHomeTokens.ink,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: c.editable ? () => _date(context) : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    backgroundColor: MomHomeTokens.surface,
                    foregroundColor: MomHomeTokens.ink,
                    side: const BorderSide(color: MomHomeTokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.recordedOn.toString())),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_month_outlined, size: 18),
                    ],
                  ),
                ),
                if (c.kind == BabyRecordKind.growth) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '系统展示测量变化，不把单次结果直接解释为“正常”或“异常”。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (!c.hasActiveSleep || c.editing || _adjustActiveSleep) ...[
          SizedBox(
            height: c.kind == BabyRecordKind.feeding ? 0 : MomCozySpacing.card,
          ),
          ExpansionTile(
            key: PageStorageKey('baby-note-${c.kind.name}'),
            initiallyExpanded: c.note.isNotEmpty,
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.all(12),
            backgroundColor: MomHomeTokens.surface,
            collapsedBackgroundColor: MomHomeTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: MomHomeTokens.border),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: MomHomeTokens.border),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                const Text(
                  '补充备注',
                  style: TextStyle(fontSize: 14, color: MomHomeTokens.ink),
                ),
                Text(
                  c.note.isEmpty ? '可选，不参与统计' : '已填写',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MomHomeTokens.secondary,
                  ),
                ),
              ],
            ),
            children: [
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
          ),
        ],
        if (c.kind == BabyRecordKind.feeding)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MomCozyLineIcon(
                  MomCozyLineGlyph.shield,
                  size: 14,
                  color: MomHomeTokens.teal,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '系统统计次数、时长和已填写奶量；亲喂时长不会换算成摄入量。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
