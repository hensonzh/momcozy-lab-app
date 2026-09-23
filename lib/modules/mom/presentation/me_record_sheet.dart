import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../baby/presentation/baby_design.dart';
import '../application/me_controller.dart';
import '../domain/me_experience.dart';
import 'me_design.dart';

Future<void> showMeRecordSheet(
  BuildContext context,
  MeController controller,
  MeMetric kind,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xfffffcf9),
  barrierColor: MeDesign.ink.withValues(alpha: .30),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => MeRecordSheet(controller: controller, kind: kind),
);
const meQuickOptions = {
  MeMetric.energy: ['有力气', '还撑得住', '很疲惫'],
  MeMetric.sleep: ['少于 3 小时', '3–4 小时', '4–5 小时', '5–6 小时', '6 小时以上', '不确定'],
  MeMetric.mood: ['不太好', '一般', '不错'],
};

class MeRecordSheet extends StatefulWidget {
  const MeRecordSheet({
    super.key,
    required this.controller,
    required this.kind,
  });
  final MeController controller;
  final MeMetric kind;
  @override
  State<MeRecordSheet> createState() => _MeRecordSheetState();
}

class _MeRecordSheetState extends State<MeRecordSheet> {
  final id = const Uuid().v4();
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      note = TextEditingController(),
      duration = TextEditingController();
  String? value, side, phase, impact, swallow, carer;
  String action = '添加一袋';
  double pain = 0;
  bool busy = false, failed = false;
  late DateTime at = widget.controller.now();
  late final MeObservation? linkedFeed = _linkedFeed();
  MeObservation? _linkedFeed() {
    if (![
      MeMetric.pain,
      MeMetric.latch,
      MeMetric.bottle,
    ].contains(widget.kind)) {
      return null;
    }
    final today = widget.controller.now();
    final records =
        (widget.controller.state?.records ?? const <MeObservation>[])
            .where(
              (e) =>
                  e.kind == MeMetric.feed &&
                  e.occurredAt.year == today.year &&
                  e.occurredAt.month == today.month &&
                  e.occurredAt.day == today.day &&
                  (widget.kind == MeMetric.pain ||
                      (widget.kind == MeMetric.latch
                          ? e.fields['feeding_method'] == 'breastfeeding'
                          : e.fields['feeding_method'] != 'breastfeeding')),
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return records.firstOrNull;
  }

  String get linkedHelp {
    final record = linkedFeed!;
    final time =
        '${record.occurredAt.hour.toString().padLeft(2, '0')}:${record.occurredAt.minute.toString().padLeft(2, '0')}';
    final method = record.fields['feeding_method'] == 'breastfeeding'
        ? '亲喂'
        : '瓶喂';
    return '关联今天 $time 的$method记录。';
  }

  bool get quick => meQuickOptions.containsKey(widget.kind);
  bool get valid => quick
      ? value != null
      : widget.kind == MeMetric.pain
      ? side != null && phase != null && impact != null
      : (widget.kind == MeMetric.latch || widget.kind == MeMetric.bottle)
      ? value != null
      : double.tryParse(amount.text) != null &&
            (widget.kind != MeMetric.pump || side != null);
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !valid || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.controller.saveRecord(
        MeObservation(
          id: id,
          kind: widget.kind,
          occurredAt: at,
          value:
              quick ||
                  (widget.kind == MeMetric.latch ||
                      widget.kind == MeMetric.bottle)
              ? value!
              : widget.kind == MeMetric.pain
              ? '${pain.round()} / 10'
              : '${amount.text} ml',
          fields: {
            if (linkedFeed != null) 'feeding_record_id': linkedFeed!.id,
            if (side != null) 'side': side,
            if (phase != null) 'phase': phase,
            if (impact != null) 'impact': impact,
            if (swallow != null) 'swallow': swallow,
            if (carer != null) 'carer': carer,
            if (widget.kind == MeMetric.pain) 'pain': pain.round(),
            if (!quick) 'note': note.text,
            if (widget.kind == MeMetric.storage) 'action': action,
            if (amount.text.isNotEmpty) 'volume_ml': double.parse(amount.text),
            if (duration.text.isNotEmpty)
              'duration_minutes': int.parse(duration.text),
          },
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  Widget field(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: MeDesign.text(12, color: MeDesign.muted, line: 18)),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
  Widget dropdown(
    String title,
    List<String> options,
    String? current,
    ValueChanged<String?> changed,
  ) => field(
    title,
    DropdownButtonFormField<String>(
      initialValue: current,
      items: options
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: busy ? null : changed,
      decoration: const InputDecoration(hintText: '请选择'),
      style: MeDesign.text(14),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final title = switch (kind) {
      MeMetric.energy => '今天有精神吗？',
      MeMetric.sleep => '昨晚大概睡了多久？',
      MeMetric.mood => '现在的心情怎么样？',
      MeMetric.pain => '这次喂奶疼不疼？',
      MeMetric.latch => '宝宝这次含得稳吗？',
      MeMetric.bottle => '宝宝这次愿意吃奶瓶吗？',
      MeMetric.storage => '更新储奶记录',
      _ => '记录一次泵奶',
    };
    return PopScope(
      canPop: !busy,
      child: Theme(
        data: BabyDesign.theme(Theme.of(context)),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).top -
                    24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 39,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xffd9ceca),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 42,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: MeDesign.text(
                                    18,
                                    weight: FontWeight.w700,
                                    line: 27,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(14, 0),
                                child: IconButton(
                                  tooltip: '关闭',
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: Text(
                                    '×',
                                    style: MeDesign.text(
                                      22,
                                      color: MeDesign.muted,
                                      line: 33,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (quick) ...[
                          Text(
                            '只记录你现在的感受，之后随时可以更新。',
                            style: MeDesign.text(
                              12,
                              color: MeDesign.muted,
                              line: 18,
                            ),
                          ),
                          const SizedBox(height: 27),
                          LayoutBuilder(
                            builder: (context, box) {
                              final columns =
                                  MediaQuery.textScalerOf(context).scale(12) >
                                      18
                                  ? 2
                                  : 3;
                              return Wrap(
                                spacing: 7,
                                runSpacing: 14,
                                children: [
                                  for (final option in meQuickOptions[kind]!)
                                    SizedBox(
                                      width:
                                          (box.maxWidth - 7 * (columns - 1)) /
                                          columns,
                                      child: Semantics(
                                        selected: value == option,
                                        child: OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => setState(
                                                  () => value = option,
                                                ),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              44,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 10,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            backgroundColor: value == option
                                                ? BabyDesign.selected
                                                : const Color(0xfffffcf9),
                                            foregroundColor: value == option
                                                ? BabyDesign.selectedInk
                                                : MeDesign.rose,
                                            side: BorderSide(
                                              color: value == option
                                                  ? Colors.transparent
                                                  : const Color(0xffe9dfdc),
                                            ),
                                            shape: const StadiumBorder(),
                                            textStyle: MeDesign.text(
                                              12,
                                              weight: FontWeight.w700,
                                              line: 21,
                                            ),
                                          ),
                                          child: Text(
                                            option,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 74),
                          Text(
                            '不需要补齐其他项目。',
                            style: MeDesign.text(12, color: MeDesign.muted),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          Text(
                            linkedFeed != null
                                ? linkedHelp
                                : switch (kind) {
                                    MeMetric.pump => '记录实际泵出的量，不设置必须完成的目标。',
                                    MeMetric.storage => '添加或取用奶袋，让库存保持清楚。',
                                    MeMetric.bottle => '可以关联已有瓶喂，不重复记录奶量。',
                                    _ => '记录这次喂奶时的实际感受。',
                                  },
                            style: MeDesign.text(
                              12,
                              color: MeDesign.muted,
                              line: 18,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (kind == MeMetric.pain) ...[
                            field(
                              '哪一侧不舒服？',
                              BabyChoices<String>(
                                options: const {
                                  '左侧': '左侧',
                                  '右侧': '右侧',
                                  '两侧': '两侧',
                                },
                                selected: side,
                                onChanged: (v) => setState(() => side = v),
                                columns: 3,
                                enabled: !busy,
                                height: 44,
                                radius: 22,
                              ),
                            ),
                            dropdown(
                              '什么时候疼？',
                              ['刚开始含奶时', '喂奶过程中', '喂奶后', '泵奶时'],
                              phase,
                              (v) => setState(() => phase = v),
                            ),
                            field(
                              '疼痛程度',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${pain.round()} / 10',
                                    style: MeDesign.text(
                                      22,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  Slider(
                                    value: pain,
                                    max: 10,
                                    divisions: 10,
                                    activeColor: MeDesign.rose,
                                    onChanged: busy
                                        ? null
                                        : (v) => setState(() => pain = v),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '0 无痛',
                                        style: MeDesign.text(
                                          11,
                                          color: MeDesign.muted,
                                        ),
                                      ),
                                      Text(
                                        '10 最强烈',
                                        style: MeDesign.text(
                                          11,
                                          color: MeDesign.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            dropdown(
                              '对这次喂奶的影响',
                              ['可以继续喂', '需要暂停', '无法继续'],
                              impact,
                              (v) => setState(() => impact = v),
                            ),
                          ],
                          if (kind == MeMetric.latch) ...[
                            dropdown(
                              '含住以后怎么样？',
                              ['含得稳', '容易松开', '含不住'],
                              value,
                              (v) => setState(() => value = v),
                            ),
                            dropdown(
                              '有观察到吞咽吗？（可选）',
                              ['有', '没有', '不确定'],
                              swallow,
                              (v) => setState(() => swallow = v),
                            ),
                          ],
                          if (kind == MeMetric.bottle) ...[
                            dropdown(
                              '宝宝的接受情况',
                              ['愿意吃', '愿意吃一些', '不太愿意', '不愿意吃'],
                              value,
                              (v) => setState(() => value = v),
                            ),
                            dropdown(
                              '谁来喂？（可选）',
                              ['自己', '伴侣', '家人', '专业照护人员'],
                              carer,
                              (v) => setState(() => carer = v),
                            ),
                          ],
                          if (kind == MeMetric.storage) ...[
                            dropdown(
                              '这次要做什么？',
                              ['添加一袋', '取用一袋'],
                              action,
                              (v) => setState(() => action = v!),
                            ),
                          ],
                          if (kind == MeMetric.pump ||
                              kind == MeMetric.storage ||
                              kind == MeMetric.bottle) ...[
                            field(
                              kind == MeMetric.storage
                                  ? '储存日期'
                                  : kind == MeMetric.bottle
                                  ? '记录时间'
                                  : '泵奶时间',
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: at,
                                          firstDate: DateTime(2000),
                                          lastDate: widget.controller.now(),
                                        );
                                        if (date == null || !context.mounted) {
                                          return;
                                        }
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.fromDateTime(
                                            at,
                                          ),
                                        );
                                        if (time != null && mounted) {
                                          final v = DateTime(
                                            date.year,
                                            date.month,
                                            date.day,
                                            time.hour,
                                            time.minute,
                                          );
                                          if (!v.isAfter(
                                            widget.controller.now(),
                                          )) {
                                            setState(() => at = v);
                                          }
                                        }
                                      },
                                child: Text(
                                  '${at.year}-${at.month}-${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                            if (kind != MeMetric.bottle)
                              field(
                                kind == MeMetric.storage ? '这袋有多少？' : '这次泵出多少？',
                                TextFormField(
                                  controller: amount,
                                  enabled: !busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    suffixText: 'ml',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    return n == null ||
                                            !n.isFinite ||
                                            n <= 0 ||
                                            n > 3000
                                        ? '请输入有效奶量'
                                        : null;
                                  },
                                ),
                              ),
                          ],
                          if (kind == MeMetric.pump) ...[
                            dropdown(
                              '泵了哪一侧？',
                              ['左侧', '右侧', '两侧'],
                              side,
                              (v) => setState(() => side = v),
                            ),
                            field(
                              '时长（可选）',
                              TextFormField(
                                controller: duration,
                                enabled: !busy,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  suffixText: '分钟',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  final n = int.tryParse(v);
                                  return n == null || n <= 0 || n > 240
                                      ? '请输入 1–240 分钟'
                                      : null;
                                },
                              ),
                            ),
                          ],
                          if (kind == MeMetric.pain || kind == MeMetric.latch)
                            field(
                              '补充变化或备注（可选）',
                              TextFormField(
                                controller: note,
                                enabled: !busy,
                                maxLength: 500,
                                maxLines: 2,
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                        if (failed) ...[
                          const MeError(),
                          const SizedBox(height: 12),
                        ],
                        MeButton(
                          '保存记录',
                          onPressed: valid ? save : null,
                          busy: busy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
