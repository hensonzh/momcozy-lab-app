import 'dart:convert';
import 'package:flutter/material.dart';
import '../application/me_controller.dart';
import 'me_design.dart';

const meProfileGroups = ['基本信息', '分娩情况', '喂养方式', '照护与补充信息'];
const meProfileChoices = <String, Map<String, String>>{
  'delivery_count': {'1': '第1次', '2': '第2次', '3': '第3次及以上'},
  'baby_count': {'1': '单胎', '2': '双胞胎', '3': '三胞胎及以上'},
  'current_delivery_method': {'vaginal': '阴道分娩（顺产）', 'cesarean': '剖宫产'},
  'feeding_methods': {
    'direct': '母乳亲喂',
    'expressed': '母乳瓶喂',
    'formula': '配方奶瓶喂',
  },
  'feeding_preference': {
    'breast': '母乳喂养',
    'formula': '配方奶喂养',
    'mixed': '混合喂养',
    'undecided': '还没想好',
  },
  'caregivers': {
    'partner': '伴侣',
    'family': '家人',
    'professional': '专业照护人员',
    'self': '主要由我照护',
  },
};

class MeProfilePage extends StatelessWidget {
  const MeProfilePage({super.key, required this.controller});
  final MeController controller;
  String value(String key) =>
      controller.state?.profile[key]?.toString() ?? '未填写';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MePage(
      title: '个人档案',
      background: MeDesign.profileBackground,
      bodyPadding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '让 Cozymate 更了解你',
            style: MeDesign.text(22, weight: FontWeight.w700, line: 32),
          ),
          const SizedBox(height: 6),
          Text(
            '按意愿填写，之后可以随时修改。',
            style: MeDesign.text(13, color: MeDesign.muted, line: 19),
          ),
          const SizedBox(height: 25),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MeProfileEditor(controller: controller, group: i),
                  ),
                ),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: [86.0, 138.0, 112.0, 86.0][i],
                  ),
                  padding: const EdgeInsets.fromLTRB(17, 13, 17, 23),
                  decoration: MeDesign.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meProfileGroups[i],
                              style: MeDesign.text(
                                15,
                                weight: FontWeight.w700,
                                line: 22,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(
                              '编辑 ›',
                              style: MeDesign.text(
                                13,
                                color: MeDesign.rose,
                                line: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      for (final line in _summary(i)) ...[
                        Text(
                          line,
                          style: MeDesign.text(
                            13,
                            color: const Color(0xff807975),
                            line: 19,
                          ),
                        ),
                        if (line != _summary(i).last) const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  List<String> _summary(int group) {
    final profile = controller.state?.profile ?? {};
    final birth = DateTime.tryParse(value('actual_delivery_date'));
    final weeks = profile['gestation_weeks'];
    final days = profile['gestation_days'];
    final delivery = [
      'delivery_count',
      'baby_count',
      'current_delivery_method',
    ];
    return switch (group) {
      0 => ['${value('preferred_name')} · 年龄${value('age')}'],
      1 => [
        '分娩日期  ${birth == null ? '未填写' : '${birth.year}年${birth.month}月${birth.day}日'}',
        '分娩孕周  ${weeks == null ? '未填写' : '$weeks 周${days == null ? '' : ' $days 天'}'}',
        delivery.every((e) => profile[e] == null)
            ? '分娩胎次、宝宝数量、分娩方式待填写'
            : delivery.map(_labels).join(' · '),
      ],
      2 => [
        '目前的喂养方式  ${_labels('feeding_methods')}',
        '倾向的喂养方式  ${_labels('feeding_preference')}',
      ],
      _ => ['照护支持、返工安排与其他情况'],
    };
  }

  String _labels(String key) {
    final value = controller.state?.profile[key];
    if (value == null) return '未填写';
    return (value is List ? value : [value])
        .map(
          (e) =>
              meProfileChoices[key]?[key == 'delivery_count' &&
                      (int.tryParse(e.toString()) ?? 0) >= 3
                  ? '3'
                  : e.toString()] ??
              e,
        )
        .join('、');
  }
}

class MeProfileEditor extends StatefulWidget {
  const MeProfileEditor({
    super.key,
    required this.controller,
    required this.group,
  });
  final MeController controller;
  final int group;
  @override
  State<MeProfileEditor> createState() => _MeProfileEditorState();
}

class _MeProfileEditorState extends State<MeProfileEditor> {
  late final initial = Map<String, Object?>.from(
    widget.controller.state?.profile ?? {},
  );
  late final draft = Map<String, Object?>.from(initial);
  final form = GlobalKey<FormState>();
  bool busy = false, failed = false, allowExit = false;
  bool get dirty => jsonEncode(draft) != jsonEncode(initial);
  Future<void> back() async {
    if (busy) return;
    if (!dirty || await meDiscard(context)) {
      if (mounted) {
        setState(() => allowExit = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> save() async {
    if (busy || !dirty || !form.currentState!.validate()) return;
    final changes = {
      for (final e in draft.entries)
        if (jsonEncode(e.value) != jsonEncode(initial[e.key])) e.key: e.value,
    };
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.controller.saveProfile(changes);
      if (mounted) {
        setState(() => allowExit = true);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  Widget label(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(name, style: MeDesign.text(15, weight: FontWeight.w500)),
  );
  Widget input(
    String key,
    String name, {
    bool numeric = false,
    int? limit,
    String? hint,
    int lines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      label(name),
      TextFormField(
        initialValue: draft[key]?.toString(),
        enabled: !busy,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        maxLines: lines,
        maxLength: limit,
        style: MeDesign.text(16),
        decoration: InputDecoration(
          hintText: hint ?? '填写$name',
          filled: true,
          fillColor: MeDesign.surface,
        ),
        onChanged: (v) => setState(
          () => draft[key] = v.isEmpty
              ? null
              : numeric
              ? int.tryParse(v)
              : v,
        ),
        validator: (v) {
          if (v == null || v.isEmpty) {
            return key == 'preferred_name' ? '请填写称呼' : null;
          }
          if (numeric) {
            final n = int.tryParse(v);
            if (n == null) return '请输入整数';
            if (key == 'age' && (n < 12 || n > 70)) return '请输入 12–70 岁';
            if (key == 'gestation_weeks' && (n < 20 || n > 45)) {
              return '请输入 20–45 周';
            }
            if (key == 'gestation_days' && (n < 0 || n > 6)) return '请输入 0–6 天';
          }
          return null;
        },
      ),
      const SizedBox(height: 26),
    ],
  );
  Widget choices(String key, String name, {bool multi = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      label(name),
      LayoutBuilder(
        builder: (context, box) {
          final entries = meProfileChoices[key]!.entries.toList();
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: (box.maxWidth - 12) / 2,
                  child: MeChoice(
                    entry.value,
                    selected: multi
                        ? (draft[key] as List? ?? []).contains(entry.key)
                        : key == 'delivery_count' && entry.key == '3'
                        ? (draft[key] as int? ?? 0) >= 3
                        : draft[key]?.toString() == entry.key,
                    onTap: busy
                        ? null
                        : () => setState(() {
                            if (multi) {
                              final selected = List<String>.from(
                                draft[key] as List? ?? [],
                              );
                              selected.contains(entry.key)
                                  ? selected.remove(entry.key)
                                  : selected.add(entry.key);
                              draft[key] = meProfileChoices[key]!.keys
                                  .where(selected.contains)
                                  .toList();
                            } else {
                              if (key == 'delivery_count' &&
                                  entry.key == '3' &&
                                  (draft[key] as int? ?? 0) >= 3) {
                                return;
                              }
                              draft[key] =
                                  ['delivery_count', 'baby_count'].contains(key)
                                  ? int.parse(entry.key)
                                  : entry.key;
                            }
                          }),
                    height: 48,
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 26),
    ],
  );
  Widget dateField(String key, String name, {bool future = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      label(name),
      OutlinedButton(
        onPressed: busy
            ? null
            : () async {
                final today = widget.controller.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(draft[key]?.toString() ?? '') ?? today,
                  firstDate: DateTime(1950),
                  lastDate: future ? DateTime(today.year + 10) : today,
                );
                if (date != null && mounted) {
                  setState(
                    () => draft[key] =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: MeDesign.surface,
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: MeDesign.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          draft[key]?.toString() ?? '选择日期${future ? '（选填）' : ''}',
          style: MeDesign.text(
            16,
            color: draft[key] == null ? MeDesign.muted : MeDesign.ink,
          ),
        ),
      ),
      const SizedBox(height: 26),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowExit || (!dirty && !busy),
    onPopInvokedWithResult: (p, _) {
      if (!p) back();
    },
    child: MePage(
      title: meProfileGroups[widget.group],
      onBack: back,
      footer: MeButton('保存', onPressed: dirty ? save : null, busy: busy),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.group == 0) ...[
              Text('怎么称呼你？', style: MeDesign.text(24, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                '填写称呼和年龄，帮助 Cozymate 了解你的情况。',
                style: MeDesign.text(14, color: MeDesign.muted),
              ),
              const SizedBox(height: 40),
              input('preferred_name', '称呼'),
              input('age', '年龄', numeric: true),
            ],
            if (widget.group == 1) ...[
              Text('关于这次分娩', style: MeDesign.text(24, weight: FontWeight.w700)),
              const SizedBox(height: 30),
              dateField('actual_delivery_date', '分娩日期'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: input(
                      'gestation_weeks',
                      '分娩时孕周',
                      numeric: true,
                      hint: '周',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: input(
                      'gestation_days',
                      '天',
                      numeric: true,
                      hint: '0–6',
                    ),
                  ),
                ],
              ),
              choices('delivery_count', '这是第几次分娩'),
              choices('baby_count', '本次宝宝数量'),
              choices('current_delivery_method', '分娩方式'),
            ],
            if (widget.group == 2) ...[
              choices('feeding_methods', '目前的喂养方式 · 可多选', multi: true),
              const SizedBox(height: 24),
              choices('feeding_preference', '倾向的喂养方式 · 单选'),
            ],
            if (widget.group == 3) ...[
              choices('caregivers', '平时谁会帮忙照护 · 可多选', multi: true),
              const SizedBox(height: 24),
              dateField('return_to_work_date', '计划返工日期', future: true),
              input(
                'additional_context',
                '需要特别了解的情况',
                lines: 5,
                limit: 500,
                hint: '例如恢复情况、既往健康问题、正在用药，或其他想补充的事。',
              ),
            ],
            if (failed) const MeError(),
          ],
        ),
      ),
    ),
  );
}
