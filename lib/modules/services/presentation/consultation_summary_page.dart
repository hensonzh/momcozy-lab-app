import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/zoned_time.dart';
import '../application/summary_controller.dart';

const careTaskStatusLabels = <CareTaskStatus, String>{
  CareTaskStatus.pending: '待完成',
  CareTaskStatus.inProgress: '进行中',
  CareTaskStatus.completed: '已完成',
  CareTaskStatus.skipped: '暂时跳过',
};

class ConsultationSummaryPage extends StatefulWidget {
  const ConsultationSummaryPage({
    super.key,
    required this.createController,
    required this.onBack,
    required this.onProgress,
  });
  final CareSummaryController Function() createController;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onProgress;
  @override
  State<ConsultationSummaryPage> createState() =>
      _ConsultationSummaryPageState();
}

class _ConsultationSummaryPageState extends State<ConsultationSummaryPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.load();
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (controller.data?.publication == null &&
          !controller.loading &&
          controller.failure == null) {
        controller.load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.load();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MomCozyColors.background,
    appBar: AppBar(
      title: const Text('本次咨询总结'),
      leading: BackButton(onPressed: widget.onBack),
    ),
    body: MomCozyPageBody(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MomCozyInsets.page,
            children: [
              if (controller.loading || controller.busy)
                const LinearProgressIndicator(),
              if (controller.failure case final failure?)
                ProductErrorView(
                  failure: failure,
                  onRetry: controller.busy ? null : controller.retry,
                ),
              if (controller.failure?.code == 'plan_superseded')
                const Text('专家发布了新方案，请重新载入后继续。'),
              if (controller.uncertain)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('反馈结果尚未确认，请重试这次更新。'),
                ),
              if (controller.data != null) ..._content(context),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _content(BuildContext context) {
    final data = controller.data!, plan = data.publication;
    if (plan == null) {
      final failed = [
        ConsultationStatus.failed,
        ConsultationStatus.noShow,
        ConsultationStatus.cancelled,
      ].contains(data.consultation?.status);
      final ended = data.appointment.status == AppointmentStatus.completed;
      return [
        Padding(
          padding: const EdgeInsets.only(top: 52),
          child: Column(
            children: [
              Icon(
                failed ? Icons.event_busy_outlined : Icons.schedule_outlined,
                size: 44,
                color: MomCozyColors.care,
              ),
              const SizedBox(height: MomCozySpacing.card),
              Text(
                failed
                    ? '本次咨询未完成'
                    : ended
                    ? '${data.appointment.providerName} 正在整理本次建议'
                    : '还没有可查看的总结',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MomCozySpacing.content),
              Text(
                failed
                    ? '可返回服务进度查看后续安排。'
                    : ended
                    ? '专家发布后，这里会显示行动建议、观察重点和后续安排。'
                    : '咨询结束后，经 IBCLC 确认的建议会显示在这里。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  height: 1.7,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
              const SizedBox(height: MomCozySpacing.section),
              OutlinedButton(
                onPressed: () => widget.onProgress(data.episode),
                child: const Text('查看服务进度'),
              ),
            ],
          ),
        ),
      ];
    }
    final primary =
        plan.tasks
            .where(
              (value) => [
                CareTaskStatus.pending,
                CareTaskStatus.inProgress,
              ].contains(value.status),
            )
            .firstOrNull ??
        plan.tasks.firstOrNull;
    final next = plan.tasks.where((value) => value != primary).toList();
    return [
      Text(
        '${plan.publisherName} 给你的总结',
        style: const TextStyle(
          color: MomCozyColors.care,
          fontSize: MomCozyTypography.secondarySize,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: MomCozySpacing.page),
      Text(
        '“${plan.title}”',
        style: const TextStyle(
          fontSize: MomCozyTypography.pageTitleSize,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: MomCozySpacing.page),
      Text(
        plan.summary,
        style: const TextStyle(
          fontSize: MomCozyTypography.bodySize,
          height: 1.85,
        ),
      ),
      const SizedBox(height: MomCozySpacing.card),
      Row(
        children: [
          CircleAvatar(
            backgroundColor: MomCozyColors.careSoft,
            child: Text(
              plan.publisherName.characters.first,
              style: const TextStyle(color: MomCozyColors.care),
            ),
          ),
          const SizedBox(width: MomCozySpacing.content),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.publisherName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${appointmentDay(plan.publishedAt, data.appointment.timezone)} 已确认',
                  style: const TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: MomCozySpacing.homeBottom),
      if (primary != null)
        MomCozySurface(
          color: MomCozyColors.careSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今天先做这一件事',
                style: TextStyle(
                  color: MomCozyColors.care,
                  fontSize: MomCozyTypography.captionSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: MomCozySpacing.statusGap),
              Text(
                primary.content.title,
                style: const TextStyle(
                  fontSize: MomCozyTypography.headingSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: MomCozySpacing.statusGap),
              Text(
                primary.content.description,
                style: const TextStyle(height: 1.8),
              ),
              const SizedBox(height: MomCozySpacing.page),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _task(primary.content.sourceKey),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('查看怎么做'),
                  ),
                  Text(
                    careTaskStatusLabels[primary.status]!,
                    style: const TextStyle(
                      color: MomCozyColors.care,
                      fontSize: MomCozyTypography.captionSize,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (next.isNotEmpty) ...[
        const SizedBox(height: MomCozySpacing.spacious),
        _heading('接下来几天', '一次只做一小步'),
        const SizedBox(height: MomCozySpacing.headingGap),
        for (final (index, task) in next.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: MomCozyColors.secondary,
                  child: Text(
                    '${index + 2}',
                    style: const TextStyle(
                      fontSize: MomCozyTypography.captionSize,
                    ),
                  ),
                ),
                const SizedBox(width: MomCozySpacing.content),
                Expanded(
                  child: InkWell(
                    onTap: () => _task(task.content.sourceKey),
                    borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                    child: Padding(
                      padding: const EdgeInsets.all(MomCozySpacing.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${task.content.dueLabel} · ${careTaskStatusLabels[task.status]}',
                            style: const TextStyle(
                              color: MomCozyColors.mutedForeground,
                              fontSize: MomCozyTypography.captionSize,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.content.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: MomCozyTypography.titleSize,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.content.description,
                            style: const TextStyle(height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: MomCozySpacing.spacious),
      _heading('留意这些变化', '不用记得很完整'),
      const SizedBox(height: MomCozySpacing.headingGap),
      const Text(
        '留意下一次喂养时的真实感受，看看是否更接近我们共同确认的目标。',
        style: TextStyle(height: 1.8),
      ),
      for (final goal in plan.goals)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check, color: MomCozyColors.care, size: 18),
              const SizedBox(width: MomCozySpacing.statusGap),
              Expanded(child: Text(goal, style: const TextStyle(height: 1.7))),
            ],
          ),
        ),
      const SizedBox(height: MomCozySpacing.homeBottom),
      MomCozySurface(
        color: MomCozyColors.secondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '需要更多帮助时',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MomCozySpacing.compact),
            Text(
              '如果执行后仍不舒服或有新的担心，记录下变化，下次跟进时告诉 ${plan.publisherName}。紧急情况请联系当地急救服务。',
              style: const TextStyle(
                fontSize: MomCozyTypography.secondarySize,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: MomCozySpacing.card),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          '咨询与服务信息',
          style: TextStyle(fontSize: MomCozyTypography.bodySize),
        ),
        subtitle: Text(
          appointmentDay(data.appointment.startsAt, data.appointment.timezone),
          style: const TextStyle(fontSize: MomCozyTypography.captionSize),
        ),
        children: [
          _metadata(
            '本次咨询',
            zonedRange(
              data.appointment.startsAt,
              data.appointment.endsAt,
              data.appointment.timezone,
            ),
          ),
          _metadata(
            '服务周期',
            data.episode.endsAt == null
                ? '待确认'
                : '至 ${appointmentDay(data.episode.endsAt!, data.appointment.timezone)}',
          ),
          _metadata('剩余咨询', '${data.episode.remainingSessions} 次'),
          _metadata('方案版本', 'v${plan.revision}'),
          TextButton(
            onPressed: () => widget.onProgress(data.episode),
            child: const Text('查看服务进度'),
          ),
        ],
      ),
    ];
  }

  Widget _heading(String title, String supporting) => Wrap(
    spacing: 12,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: MomCozyTypography.sectionSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        supporting,
        style: const TextStyle(
          fontSize: MomCozyTypography.labelSize,
          color: MomCozyColors.mutedForeground,
        ),
      ),
    ],
  );
  Widget _metadata(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: MomCozyColors.mutedForeground),
          ),
        ),
        const SizedBox(width: MomCozySpacing.content),
        Expanded(flex: 2, child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _task(String sourceKey) => showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final task = controller.data?.publication?.tasks
            .where((value) => value.content.sourceKey == sourceKey)
            .firstOrNull;
        return AlertDialog(
          title: Text(task?.content.title ?? '方案已更新'),
          content: SizedBox(
            width: 390,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task != null) ...[
                    Text(
                      task.content.description,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: MomCozySpacing.page),
                    Text(
                      '${task.content.category} · ${task.content.dueLabel}',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                    if (task.content.scheduledDate != null)
                      Text('安排日期：${task.content.scheduledDate}'),
                    const SizedBox(height: MomCozySpacing.card),
                    const Text('我的进度'),
                    const SizedBox(height: MomCozySpacing.compact),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in CareTaskStatus.values)
                          ChoiceChip(
                            label: Text(careTaskStatusLabels[status]!),
                            selected: task.status == status,
                            onSelected: controller.canUpdate
                                ? (_) => controller.update(task, status)
                                : null,
                          ),
                      ],
                    ),
                  ],
                  if (controller.busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (controller.failure case final failure?)
                    ProductErrorView(
                      failure: failure,
                      onRetry: controller.busy ? null : controller.retry,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    ),
  );
}
