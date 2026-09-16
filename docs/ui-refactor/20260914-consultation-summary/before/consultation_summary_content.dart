import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../domain/care/documentation.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/zoned_time.dart';

class ConsultationSummaryContent extends StatelessWidget {
  const ConsultationSummaryContent({
    super.key,
    required this.data,
    required this.onTask,
    required this.onProgress,
    this.onPlan,
  });
  final PatientCareSummary data;
  final ValueChanged<String> onTask;
  final VoidCallback onProgress;
  final VoidCallback? onPlan;

  Text _text(
    String text,
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.55,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
    ),
  );
  Widget _heading(String title, String hint) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 12,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _text(title, 17, weight: FontWeight.w700),
      _text(hint, 10, color: MomCozyColors.mutedForeground),
    ],
  );
  Widget _kicker(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _text(
      text,
      11,
      color: MomCozyColors.primaryDark,
      weight: FontWeight.w800,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final plan = data.publication;
    if (plan == null) {
      final failed = [
        ConsultationStatus.failed,
        ConsultationStatus.noShow,
        ConsultationStatus.cancelled,
      ].contains(data.consultation?.status);
      final ended = data.appointment.status == AppointmentStatus.completed;
      return SummaryStateCard(
        title: failed
            ? '本次咨询未完成'
            : ended
            ? '${data.appointment.providerName} 正在整理本次建议'
            : '还没有可查看的总结',
        description: failed
            ? '可返回服务进度查看后续安排。'
            : ended
            ? '专家发布后，这里会显示行动建议、观察重点和后续安排。'
            : '咨询结束后，经 IBCLC 确认的建议会显示在这里。',
        pending: ended && !failed,
        action: TextButton(onPressed: onProgress, child: const Text('查看服务进度')),
      );
    }
    final primary =
        plan.tasks
            .where(
              (task) =>
                  task.status == CareTaskStatus.pending ||
                  task.status == CareTaskStatus.inProgress,
            )
            .firstOrNull ??
        plan.tasks.firstOrNull;
    final next = plan.tasks.where((task) => task != primary).toList();
    final initials = plan.publisherName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MomCozyColors.summaryIntroStart,
                MomCozyColors.summaryIntroEnd,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kicker('${plan.publisherName} 给你的总结'),
              _text(
                '“${plan.title}”',
                14,
                color: MomCozyColors.summaryTitle,
                weight: FontWeight.w700,
                height: 1.45,
              ),
              const SizedBox(height: 9),
              _text(plan.summary, 16, weight: FontWeight.w600, height: 1.65),
              const SizedBox(height: 17),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: MomCozyColors.primary,
                      child: Text(
                        initials.isEmpty ? 'IB' : initials,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MomCozyColors.card,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(plan.publisherName, 12, weight: FontWeight.w700),
                        _text(
                          '${appointmentDay(plan.publishedAt, data.appointment.timezone)} 已确认',
                          10,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (primary != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MomCozyColors.card,
              border: Border.all(color: MomCozyColors.summaryFocusBorder),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MomCozyColors.summaryTitle.withValues(alpha: .07),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kicker('今天先做这一件事'),
                _text(primary.content.title, 19, weight: FontWeight.w700),
                const SizedBox(height: 7),
                _text(
                  primary.content.description,
                  14,
                  color: MomCozyColors.mutedForeground,
                ),
                const SizedBox(height: 15),
                FilledButton(
                  onPressed: () => onTask(primary.content.sourceKey),
                  child: const Text('查看怎么做'),
                ),
              ],
            ),
          ),
        ],
        if (next.isNotEmpty) ...[
          const SizedBox(height: 18),
          _heading('接下来几天', '一次只做一小步'),
          const SizedBox(height: 10),
          const Divider(height: 1),
          for (final (index, task) in next.indexed) ...[
            InkWell(
              onTap: () => onTask(task.content.sourceKey),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: MomCozyColors.roseSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: _text(
                        '${index + 2}',
                        11,
                        color: MomCozyColors.primaryDark,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _text(
                            task.content.dueLabel,
                            10,
                            color: MomCozyColors.primaryDark,
                            weight: FontWeight.w800,
                          ),
                          const SizedBox(height: 3),
                          _text(
                            task.content.title,
                            14,
                            weight: FontWeight.w700,
                          ),
                          const SizedBox(height: 3),
                          _text(
                            task.content.description,
                            12,
                            color: MomCozyColors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
          ],
        ],
        const SizedBox(height: 18),
        _heading('留意这些变化', '不用记得很完整'),
        const SizedBox(height: 10),
        _text(
          '留意下一次喂养时的真实感受，看看是否更接近我们共同确认的目标。',
          13,
          color: MomCozyColors.mutedForeground,
        ),
        for (final goal in plan.goals)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: MomCozyColors.careSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 13,
                    color: MomCozyColors.care,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: _text(goal, 13)),
              ],
            ),
          ),
        if (onPlan != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onPlan,
              child: const Text('查看完整行动计划 →'),
            ),
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: MomCozyColors.careSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MomCozyColors.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: MomCozyColors.care,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      '需要更多帮助时',
                      14,
                      color: MomCozyColors.servicePeriodInk,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 5),
                    _text(
                      '如果执行后仍不舒服或有新的担心，先记录下变化，下次跟进时告诉 ${plan.publisherName}。紧急情况请联系当地急救服务。',
                      12,
                      color: MomCozyColors.servicePurchasedInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            color: MomCozyColors.card,
            border: Border.all(color: MomCozyColors.border),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            shape: const Border(),
            collapsedShape: const Border(),
            title: _text('咨询与服务信息', 13, weight: FontWeight.w700),
            subtitle: _text(
              '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · ${plan.publisherName}',
              10,
              color: MomCozyColors.mutedForeground,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              const Divider(height: 1),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cells = [
                    (
                      '本次咨询',
                      zonedRange(
                        data.appointment.startsAt,
                        data.appointment.endsAt,
                        data.appointment.timezone,
                      ),
                    ),
                    (
                      '服务周期',
                      data.episode.endsAt == null
                          ? '待确认'
                          : '至 ${appointmentDay(data.episode.endsAt!, data.appointment.timezone)}',
                    ),
                    ('剩余咨询', '${data.episode.remainingSessions} 次'),
                    (
                      '发布确认',
                      appointmentDay(
                        plan.publishedAt,
                        data.appointment.timezone,
                      ),
                    ),
                  ];
                  final columns =
                      MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 1 : 2;
                  return Wrap(
                    children: [
                      for (final (label, value) in cells)
                        SizedBox(
                          width: constraints.maxWidth / columns,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 11, 8, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _text(
                                  label,
                                  10,
                                  color: MomCozyColors.mutedForeground,
                                ),
                                const SizedBox(height: 3),
                                _text(value, 12, weight: FontWeight.w700),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              TextButton(onPressed: onProgress, child: const Text('查看服务进度')),
            ],
          ),
        ),
      ],
    );
  }
}

class SummaryStateCard extends StatelessWidget {
  const SummaryStateCard({
    super.key,
    required this.title,
    required this.description,
    this.pending = false,
    this.loading = false,
    this.action,
  });
  final String title, description;
  final bool pending, loading;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 265),
    padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 25),
    decoration: BoxDecoration(
      color: MomCozyColors.card,
      border: Border.all(color: MomCozyColors.border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: MomCozyColors.careSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            pending || loading
                ? Icons.schedule_outlined
                : Icons.description_outlined,
            size: 21,
            color: MomCozyColors.care,
          ),
        ),
        if (pending)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: MomCozyBadge(
              '总结整理中',
              color: MomCozyColors.care,
              background: MomCozyColors.careSoft,
            ),
          ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.55,
            color: MomCozyColors.mutedForeground,
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 17), child: action),
      ],
    ),
  );
}
