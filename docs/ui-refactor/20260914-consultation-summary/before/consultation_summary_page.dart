import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_plan.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/summary_controller.dart';
import 'consultation_summary_content.dart';
import 'service_flow_theme.dart';
import '../../../shared/widgets/product_flow_dialog.dart';

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
    this.onPlan,
  });
  final CareSummaryController Function() createController;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onProgress;
  final Future<void> Function()? onPlan;
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
  Widget build(BuildContext context) => ServiceFlowTheme(
    child: Scaffold(
      backgroundColor: MomCozyColors.background,
      appBar: AppBar(
        toolbarHeight: 52,
        centerTitle: true,
        title: const Text(
          '本次咨询总结',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 88 : 64,
        leading: TextButton(
          onPressed: widget.onBack,
          style: TextButton.styleFrom(
            foregroundColor: MomCozyColors.mutedForeground,
          ),
          child: const Text('返回'),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
        ),
      ),
      body: MomCozyPageBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (controller.loading && controller.data == null)
                  const SummaryStateCard(
                    title: '正在读取本次咨询总结',
                    description: '请稍候，不需要重复操作。',
                    loading: true,
                  )
                else if (controller.loading || controller.busy)
                  const LinearProgressIndicator(),
                if (controller.failure case final failure?)
                  if (controller.data == null)
                    SummaryStateCard(
                      title: '暂时无法读取总结',
                      description: '请重新加载，核对最新的咨询总结。',
                      action: TextButton(
                        onPressed: controller.busy ? null : controller.retry,
                        child: const Text('重新加载'),
                      ),
                    )
                  else
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
    ),
  );

  List<Widget> _content(BuildContext context) => [
    ConsultationSummaryContent(
      data: controller.data!,
      onTask: _task,
      onProgress: () => widget.onProgress(controller.data!.episode),
      onPlan: widget.onPlan == null
          ? null
          : () async {
              await widget.onPlan!();
              if (mounted) await controller.load();
            },
    ),
  ];

  Future<void> _task(String sourceKey) => showDialog<void>(
    context: context,
    animationStyle: MomCozyMotion.animationStyle(context),
    barrierDismissible: false,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final task = controller.data?.publication?.tasks
            .where((value) => value.content.sourceKey == sourceKey)
            .firstOrNull;
        return PopScope(
          canPop: !controller.busy,
          child: ServiceFlowTheme(
            child: ProductFlowDialog(
              title: task?.content.title ?? '方案已更新',
              closeLabel: '关闭行动详情',
              onClose: controller.busy ? null : () => Navigator.pop(context),
              maxHeight: 640,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (task != null) ...[
                    Text(
                      task.content.description,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${task.content.category} · ${task.content.dueLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                    if (task.content.scheduledDate != null)
                      Text(
                        '安排日期：${task.content.scheduledDate}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      '我的进度',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                  ] else
                    const Text(
                      '当前行动可能已调整，请关闭后查看最新总结。',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  if (controller.busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (controller.uncertain && !controller.busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Text(
                        '反馈结果尚未确认，请重试这次更新。',
                        style: TextStyle(fontSize: 12, height: 1.55),
                      ),
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
        );
      },
    ),
  );
}
