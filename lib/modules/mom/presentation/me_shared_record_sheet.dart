import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../baby/application/baby_record_editor_controller.dart';
import '../../baby/presentation/baby_design.dart';
import 'me_design.dart';

Future<List<BabyRecord>?> showMeSharedRecordSheet(
  BuildContext context, {
  required BabyRecordRepository repository,
  required BabyProfile baby,
  required String timezone,
  required DateTime Function() now,
  required BabyRecordKind kind,
}) async {
  final controller = BabyRecordEditorController(
    repository: repository,
    baby: baby,
    timezone: timezone,
    now: now,
    kind: kind,
  );
  try {
    return await showModalBottomSheet<List<BabyRecord>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xfffffcf9),
      barrierColor: MeDesign.ink.withValues(alpha: .30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MeSharedRecordSheet(controller: controller),
    );
  } finally {
    await controller.settled;
    controller.dispose();
  }
}

class MeSharedRecordSheet extends StatelessWidget {
  const MeSharedRecordSheet({super.key, required this.controller});
  final BabyRecordEditorController controller;
  @override
  Widget build(BuildContext context) => Theme(
    data: BabyDesign.theme(Theme.of(context)),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        final feed = c.kind == BabyRecordKind.feeding,
            diaper = c.kind == BabyRecordKind.diaper;
        final title = feed
            ? '记录一次喂奶'
            : diaper
            ? '记一次换尿布'
            : '记一次宝宝体重';
        final help = feed
            ? '这条记录也会出现在宝宝页面。'
            : diaper
            ? '与宝宝页面共用记录，不需要重复填写。'
            : '有新的测量时再记，不需要每天测量。';
        Widget field(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: MeDesign.text(12, color: MeDesign.muted, line: 18),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        );
        Widget select<T>(
          String title,
          Map<T, String> options,
          T? selected,
          ValueChanged<T?> changed,
        ) => field(
          title,
          DropdownButtonFormField<T>(
            initialValue: selected,
            onChanged: c.busy ? null : changed,
            items: [
              for (final e in options.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            decoration: const InputDecoration(hintText: '请选择'),
            style: MeDesign.text(14),
          ),
        );
        Future<void> date() async {
          final day = feed || diaper
              ? c.occurredAt
              : DateTime(
                  c.recordedOn.year,
                  c.recordedOn.month,
                  c.recordedOn.day,
                );
          final selected = await showDatePicker(
            context: context,
            initialDate: day,
            firstDate: DateTime(2000),
            lastDate: c.now(),
          );
          if (selected == null || !context.mounted) return;
          if (!feed && !diaper) {
            c.setDate(LocalDate.fromDateTime(selected));
            return;
          }
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(day),
          );
          if (time != null) {
            c.setOccurredAt(
              DateTime(
                selected.year,
                selected.month,
                selected.day,
                time.hour,
                time.minute,
              ),
            );
          }
        }

        return PopScope(
          canPop: !c.busy,
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              IconButton(
                                tooltip: '关闭',
                                onPressed: c.busy
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  color: MeDesign.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          help,
                          style: MeDesign.text(
                            12,
                            color: MeDesign.muted,
                            line: 18,
                          ),
                        ),
                        const SizedBox(height: 18),
                        field(
                          feed
                              ? '喂奶时间'
                              : diaper
                              ? '换尿布时间'
                              : '测量日期',
                          OutlinedButton(
                            onPressed: c.busy ? null : date,
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text(
                              feed || diaper
                                  ? '${c.occurredAt.month}月${c.occurredAt.day}日 ${c.occurredAt.hour.toString().padLeft(2, '0')}:${c.occurredAt.minute.toString().padLeft(2, '0')}'
                                  : c.recordedOn.toString(),
                              style: MeDesign.text(14),
                            ),
                          ),
                        ),
                        if (feed) ...[
                          select(
                            '这次怎么喂？',
                            const {
                              BabyFeedingMethod.breastfeeding: '亲喂',
                              BabyFeedingMethod.expressedMilk: '母乳瓶喂',
                              BabyFeedingMethod.formula: '配方奶瓶喂',
                            },
                            c.feedingMethod,
                            c.setFeedingMethod,
                          ),
                          if (c.feedingMethod ==
                              BabyFeedingMethod.breastfeeding) ...[
                            select(
                              '喂了哪一侧？',
                              const {
                                FeedingSide.left: '左侧',
                                FeedingSide.right: '右侧',
                                FeedingSide.both: '两侧',
                              },
                              c.feedingSide,
                              c.setSide,
                            ),
                            field(
                              '大概喂了多久？（可选）',
                              TextField(
                                enabled: c.editable,
                                keyboardType: TextInputType.number,
                                onChanged: c.setDuration,
                                decoration: const InputDecoration(
                                  suffixText: '分钟',
                                ),
                              ),
                            ),
                          ] else
                            field(
                              '这次喝了多少？',
                              TextField(
                                enabled: c.editable,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: c.setVolume,
                                decoration: const InputDecoration(
                                  suffixText: 'ml',
                                ),
                              ),
                            ),
                        ],
                        if (diaper) ...[
                          select(
                            '这次是什么情况？',
                            const {
                              DiaperKind.wet: '只有尿',
                              DiaperKind.dirty: '只有便便',
                              DiaperKind.both: '尿和便便都有',
                            },
                            c.diaperKind,
                            c.setDiaperKind,
                          ),
                          field(
                            '补充情况（可选）',
                            TextField(
                              enabled: c.editable,
                              onChanged: c.setNote,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                hintText: '点这里填写',
                              ),
                            ),
                          ),
                        ],
                        if (!feed && !diaper) ...[
                          field(
                            '测量体重',
                            TextField(
                              enabled: c.editable,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (v) =>
                                  c.setGrowthValue(GrowthMetric.weight, v),
                              decoration: const InputDecoration(
                                suffixText: 'kg',
                              ),
                            ),
                          ),
                          select(
                            '在哪里测量的？（可选）',
                            const {
                              'home': '家中测量',
                              'clinic': '医院或体检',
                              'other': '其他',
                            },
                            c.measurementSource,
                            c.setMeasurementSource,
                          ),
                        ],
                        const SizedBox(height: 48),
                        Text(
                          feed
                              ? '亲喂不需要填写毫升。'
                              : diaper
                              ? '首页显示你已经记录的次数。'
                              : '测量日期会和体重一起展示。',
                          style: MeDesign.text(
                            11,
                            color: MeDesign.muted,
                            line: 17,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (c.failure != null) ...[
                          const MeError(),
                          const SizedBox(height: 12),
                        ],
                        if (c.validation != null) ...[
                          Text(
                            c.validation!,
                            style: MeDesign.text(12, color: MeDesign.rose),
                          ),
                          const SizedBox(height: 12),
                        ],
                        MeButton(
                          '保存记录',
                          busy: c.busy,
                          onPressed: c.canSave
                              ? () async {
                                  final result = await c.save();
                                  if (result != null && context.mounted) {
                                    Navigator.pop(context, result);
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
