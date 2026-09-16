import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../shared/widgets/choice_field.dart';
import 'diary_labels.dart';

Set<T> _selected<T>(T? value) => {?value};

Widget _question(Widget child, {bool surface = true}) => Padding(
  padding: const EdgeInsets.only(bottom: MomHomeTokens.gap),
  child: surface ? MomSettingsCard(children: [child]) : child,
);

class RestFields extends StatelessWidget {
  const RestFields({super.key, required this.value, required this.onChanged});
  final MotherRest value;
  final ValueChanged<MotherRest> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          title: '昨夜大约睡了多久',
          options: sleepTotalLabels,
          selected: _selected(value.total),
          onChanged: (v) =>
              onChanged(value.copyWith(total: () => v.firstOrNull)),
        ),
      ),
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          title: '夜里大约被打断几次',
          options: interruptionsLabels,
          selected: _selected(value.interruptions),
          onChanged: (v) =>
              onChanged(value.copyWith(interruptions: () => v.firstOrNull)),
        ),
      ),
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momSegmented,
          title: '今天醒来时感觉怎样',
          options: recoveryLabels,
          selected: _selected(value.recovery),
          onChanged: (v) =>
              onChanged(value.copyWith(recovery: () => v.firstOrNull)),
        ),
      ),
      ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: MomHomeTokens.inset,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        title: _OptionalTitle(
          '补充休息情况',
          status:
              value.longestStretch != null ||
                  value.dayRest != null ||
                  value.resleepDifficulty != null ||
                  value.disruptions.isNotEmpty
              ? '已填写'
              : '可选',
        ),

        children: [
          _question(
            ChoiceField(
              style: ChoiceFieldStyle.momTiles,
              title: '最长一段完整休息',
              options: stretchLabels,
              selected: _selected(value.longestStretch),
              onChanged: (v) => onChanged(
                value.copyWith(longestStretch: () => v.firstOrNull),
              ),
            ),
            surface: false,
          ),
          _question(
            ChoiceField(
              style: ChoiceFieldStyle.momTiles,
              columns: MediaQuery.sizeOf(context).width <= 390 ? 2 : 4,
              title: '今天有没有一段不被打扰的休息',
              options: dayRestLabels,
              selected: _selected(value.dayRest),
              onChanged: (v) =>
                  onChanged(value.copyWith(dayRest: () => v.firstOrNull)),
            ),
            surface: false,
          ),
          _question(
            ChoiceField(
              style: ChoiceFieldStyle.momSegmented,
              title: '醒来后容易再睡着吗',
              options: resleepLabels,
              selected: _selected(value.resleepDifficulty),
              onChanged: (v) => onChanged(
                value.copyWith(resleepDifficulty: () => v.firstOrNull),
              ),
            ),
            surface: false,
          ),
          _question(
            ChoiceField(
              style: ChoiceFieldStyle.momTiles,
              columns: MediaQuery.sizeOf(context).width <= 390 ? 2 : 3,
              title: '影响休息的原因',
              hint: '可多选',
              options: disruptionLabels,
              selected: value.disruptions,
              multiple: true,
              onChanged: (v) => onChanged(value.copyWith(disruptions: v)),
            ),
            surface: false,
          ),
        ],
      ),
    ],
  );
}

class BodyFields extends StatelessWidget {
  const BodyFields({super.key, required this.value, required this.onChanged});
  final MotherBody value;
  final ValueChanged<MotherBody> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          title: '今天身体的电量',
          hint: '不和别人比较',
          options: energyLabels,
          selected: _selected(value.energy),
          onChanged: (v) =>
              onChanged(value.copyWith(energy: () => v.firstOrNull)),
        ),
      ),
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          columns: 2,
          title: '今天哪里最需要照顾？',
          hint: '可多选',
          options: siteLabels,
          selected: value.discomfortSites,
          multiple: true,
          onChanged: (v) => onChanged(
            value.copyWith(
              discomfortSites: v,
              severity: v.isEmpty ? () => null : null,
              impact: v.isEmpty ? () => null : null,
            ),
          ),
        ),
      ),
      if (value.discomfortSites.isNotEmpty) ...[
        _question(
          ChoiceField(
            style: ChoiceFieldStyle.momTiles,
            title: '这种不适有多难受？',
            options: severityLabels,
            selected: _selected(value.severity),
            onChanged: (v) =>
                onChanged(value.copyWith(severity: () => v.firstOrNull)),
          ),
        ),
        _question(
          ChoiceField(
            style: ChoiceFieldStyle.momTiles,
            title: '这种不适影响到你了吗？',
            options: bodyImpactLabels,
            selected: _selected(value.impact),
            onChanged: (v) =>
                onChanged(value.copyWith(impact: () => v.firstOrNull)),
          ),
        ),
      ],
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momSegmented,
          title: '和昨天相比，身体感觉',
          options: trendLabels,
          selected: _selected(value.trend),
          onChanged: (v) =>
              onChanged(value.copyWith(trend: () => v.firstOrNull)),
        ),
      ),
      ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: MomHomeTokens.inset,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        title: const _OptionalTitle('如厕与盆底', status: '可选'),

        children: [
          _question(
            ChoiceField(
              style: ChoiceFieldStyle.momTiles,
              title: '排尿',
              options: urinationLabels,
              selected: _selected(value.urination),
              onChanged: (v) =>
                  onChanged(value.copyWith(urination: () => v.firstOrNull)),
            ),
            surface: false,
          ),
          _question(
            ChoiceField(
              style: ChoiceFieldStyle.momTiles,
              title: '排便',
              options: bowelLabels,
              selected: _selected(value.bowel),
              onChanged: (v) =>
                  onChanged(value.copyWith(bowel: () => v.firstOrNull)),
            ),
            surface: false,
          ),
        ],
      ),
      const SizedBox(height: MomHomeTokens.gap),
      Text(
        '今天身体最想告诉你什么？',
        style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
      ),
      const SizedBox(height: MomHomeTokens.gap),
      Semantics(
        label: '今天身体最想告诉你什么？',
        child: TextFormField(
          initialValue: value.note,
          maxLines: 3,
          maxLength: 2000,
          style: MomHomeTokens.text(16),
          decoration: const InputDecoration(hintText: '可选'),
          onChanged: (note) => onChanged(value.copyWith(note: note)),
        ),
      ),
    ],
  );
}

class MoodFields extends StatelessWidget {
  const MoodFields({super.key, required this.value, required this.onChanged});
  final MotherMood value;
  final ValueChanged<MotherMood> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          title: '今天心里更接近哪一种',
          hint: '可以说不清楚',
          options: toneLabels,
          selected: _selected(value.tone),
          onChanged: (v) =>
              onChanged(value.copyWith(tone: () => v.firstOrNull)),
        ),
      ),
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          columns: 2,
          title: '什么一直占据着你的心？',
          hint: '可多选',
          options: pressureLabels,
          selected: value.pressures,
          multiple: true,
          exclusiveValue: MoodPressure.unclear,
          onChanged: (v) => onChanged(value.copyWith(pressures: v)),
        ),
      ),
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momSegmented,
          title: '这份难受影响到你了吗？',
          options: moodImpactLabels,
          selected: _selected(value.impact),
          onChanged: (v) =>
              onChanged(value.copyWith(impact: () => v.firstOrNull)),
        ),
      ),
      _question(
        ChoiceField(
          style: ChoiceFieldStyle.momTiles,
          columns: MediaQuery.sizeOf(context).width < 359 ? 1 : 2,
          title: '今天有人接住你吗？',
          options: supportLabels,
          selected: _selected(value.support),
          onChanged: (v) =>
              onChanged(value.copyWith(support: () => v.firstOrNull)),
        ),
      ),
    ],
  );
}

class _OptionalTitle extends StatelessWidget {
  const _OptionalTitle(this.title, {required this.status});
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      title,
      style: MomHomeTokens.text(14, weight: FontWeight.w700),
    );
    final detail = Text(
      status,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: MomHomeTokens.secondary,
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(13) > 18) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, detail],
      );
    }
    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        detail,
      ],
    );
  }
}
