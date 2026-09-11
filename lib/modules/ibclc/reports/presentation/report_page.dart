import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/care/care_report.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../../../shared/zoned_time.dart';
import '../../shared/workbench_widgets.dart';
import '../application/report_controller.dart';
import '../application/report_presentation.dart';
import 'report_content.dart';
import 'feedback_dialog.dart';

class WorkbenchReportPage extends StatefulWidget {
  const WorkbenchReportPage({
    super.key,
    required this.createController,
    required this.onBack,
    required this.onClient,
    required this.onSelection,
  });
  final WorkbenchReportController Function() createController;
  final VoidCallback onBack;
  final VoidCallback onClient;
  final void Function(String episodeId, LocalDate? date) onSelection;
  @override
  State<WorkbenchReportPage> createState() => _WorkbenchReportPageState();
}

class _WorkbenchReportPageState extends State<WorkbenchReportPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  Timer? timer;
  String? feedbackReportId;
  String feedbackDraft = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.load());
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!controller.busy) unawaited(controller.load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _feedback(CareReport report) async {
    final initial = feedbackReportId == report.id
        ? feedbackDraft
        : report.review?.feedback ?? '';
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportFeedbackDialog(
        report: report,
        initialValue: initial,
        onDraft: (value) {
          feedbackReportId = report.id;
          feedbackDraft = value;
        },
      ),
    );
    if (value != null && mounted) {
      final saved = await controller.review(
        report,
        CareReportReviewDecision.feedback,
        feedback: value,
      );
      if (saved) feedbackDraft = '';
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final client = controller.client,
          service = controller.service,
          data = controller.data,
          report = data?.report;
      return WorkbenchPageBody(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('返回今日跟进'),
            ),
          ),
          const SizedBox(height: 14),
          WorkbenchHeading(
            title: client?.displayName ?? '专业跟进',
            subtitle: 'AI 汇总问题与回答，IBCLC 核对并留下专业意见。',
            actions: [
              if (client != null)
                OutlinedButton(
                  onPressed: widget.onClient,
                  child: const Text('查看客户资料'),
                ),
              IconButton(
                tooltip: '刷新报告',
                onPressed: controller.busy ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.busy)
            const LinearProgressIndicator(semanticsLabel: '正在同步报告'),
          if (controller.failure != null) ...[
            if (controller.failure!.code == 'ai_consent_required')
              const ReportSection(
                title: '等待 AI 授权',
                child: Text('客户开启本服务的 AI 上下文授权后，才能读取或生成报告。'),
              )
            else if (controller.failure!.code == 'care_reports_unavailable')
              const ReportSection(
                title: 'AI 报告暂不可用',
                child: Text('报告生成服务尚未就绪，请稍后重试。'),
              ),
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          ],
          if (client != null && service != null) ...[
            ReportSection(
              title: '当前服务',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in client.services)
                    ChoiceChip(
                      label: Text(option.package.name),
                      selected: option.episode.id == service.episode.id,
                      onSelected: controller.saving
                          ? null
                          : (_) => widget.onSelection(option.episode.id, null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!service.caseConsent)
              const ReportSection(
                title: '等待病例授权',
                child: Text('客户尚未授权查看这项服务的病例资料。'),
              ),
            if (data != null) ...[
              ReportSection(
                title: service.episode.startsAt == null
                    ? '咨询准备'
                    : '${service.package.durationDays} 天服务周期',
                action: WorkbenchBadge(
                  serviceDayLabel(
                    service,
                    dateInTimezone(data.serverTime, data.timezone),
                    data.timezone,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '已使用 ${service.episode.totalSessions - service.episode.remainingSessions}/${service.episode.totalSessions} 次咨询${service.episode.endsAt == null ? '' : ' · ${dateInTimezone(service.episode.endsAt!, data.timezone)} 结束'}',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                    if (service.episode.startsAt != null) ...[
                      const SizedBox(height: 18),
                      _days(data),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ReportSection(
                title: data.purpose == CareReportPurpose.preparation
                    ? '咨询前整理'
                    : '${data.date} · 每日跟进',
                action: WorkbenchBadge(
                  reportStatusLabel(data.state, report?.review?.decision),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (report?.asOf != null)
                      Text(
                        '资料截至 ${dateInTimezone(report!.asOf!, data.timezone)} ${zonedClock(report.asOf!, data.timezone)} · ${data.timezone} · 第 ${report.version} 版',
                        style: const TextStyle(
                          color: MomCozyColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (data.state != CareReportState.ready)
                      Text(switch (data.state) {
                        CareReportState.notGenerated =>
                          '尚未生成这一天的报告，可汇总已授权的服务资料。',
                        CareReportState.waitingForRecord =>
                          '这个日期暂无可汇总的日常记录或完整服务对话。新增记录后可更新报告。',
                        CareReportState.queued ||
                        CareReportState.running => '报告正在处理中，完成后会自动更新。',
                        CareReportState.failed => '本次生成未完成，请重新生成后再复核。',
                        CareReportState.cancelled => '来源或授权发生变化，请重新生成后再复核。',
                        _ => '请检查这项服务的授权。',
                      }),
                    if (report != null && report.omittedCount > 0)
                      Text(
                        '有 ${report.omittedCount} 条来源未纳入本次摘要，覆盖范围不完整。',
                        style: const TextStyle(color: MomCozyColors.amber),
                      ),
                    if (data.state == CareReportState.ready)
                      const Text(
                        'AI 内容供专业核对。确认或修改意见会保存为专业复核记录。',
                        style: TextStyle(
                          color: MomCozyColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    if (report != null &&
                        data.state == CareReportState.ready &&
                        !report.reviewable)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('分配或授权已变化，重新生成后可进行复核。'),
                      ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed:
                            controller.busy ||
                                [
                                  CareReportState.queued,
                                  CareReportState.running,
                                ].contains(data.state)
                            ? null
                            : controller.generate,
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: Text(
                          data.state == CareReportState.notGenerated
                              ? '生成报告'
                              : '更新报告',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (report?.content != null) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportSection(
                      title: '智能体整理',
                      child: ReportFindings(
                        report: report!,
                        items: report.content!.summary,
                        empty: '暂无可归纳的事实。',
                      ),
                    ),
                    const SizedBox(height: 18),
                    ReportSection(
                      title: '用户自述',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '当前情绪',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          ReportFindings(
                            report: report,
                            items: report.content!.emotionalState,
                            empty: '暂无明确的情绪自述。',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '沟通偏好',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          ReportFindings(
                            report: report,
                            items: report.content!.communicationPreferences,
                            empty: '暂无明确的沟通偏好自述。',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final right = ReportSection(
                  title: '辅诊核对',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReportFindings(
                        report: report,
                        items: report.content!.checks,
                        empty: '暂无额外的待核对项。',
                      ),
                      if (report.content!.dataGaps.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          '资料缺口',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        for (final gap in report.content!.dataGaps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '• $gap',
                              style: const TextStyle(
                                color: MomCozyColors.mutedForeground,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
                return constraints.maxWidth >= 850 &&
                        MediaQuery.textScalerOf(context).scale(14) < 20
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: left),
                          const SizedBox(width: 18),
                          Expanded(flex: 2, child: right),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [left, const SizedBox(height: 18), right],
                      );
              },
            ),
            const SizedBox(height: 18),
            ReportSection(
              title: '服务对话',
              child: ReportDialogueList(report: report!),
            ),
            const SizedBox(height: 18),
            ReportSection(
              title: '专业复核',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (report.review != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            report.review!.decision ==
                                CareReportReviewDecision.confirmed
                            ? MomCozyColors.careSoft
                            : MomCozyColors.amberSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.review!.decision ==
                                    CareReportReviewDecision.confirmed
                                ? '已确认：认可这份报告及所含回答。'
                                : '已反馈：建议修改以下内容。',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (report.review!.feedback.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: SelectionArea(
                                child: Text(report.review!.feedback),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '${dateInTimezone(report.review!.createdAt, report.timezone)} ${zonedClock(report.review!.createdAt, report.timezone)} · 复核第 ${report.review!.version} 版',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    '确认表示认可报告；反馈修改需提供具体意见。',
                    style: TextStyle(
                      fontSize: 13,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: controller.busy || !report.reviewable
                            ? null
                            : () => controller.review(
                                report,
                                CareReportReviewDecision.confirmed,
                              ),
                        child: const Text('确认回答'),
                      ),
                      FilledButton(
                        onPressed: controller.busy || !report.reviewable
                            ? null
                            : () => _feedback(report),
                        child: const Text('反馈修改'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
  Widget _days(CareReportSnapshot data) {
    final service = controller.service!;
    final start = dateInTimezone(service.episode.startsAt!, data.timezone);
    final today = dateInTimezone(data.serverTime, data.timezone);
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (var index = 0; index < service.package.durationDays; index++)
          Builder(
            builder: (context) {
              final date = start.addDays(index);
              final future = date.compareTo(today) > 0;
              final record = controller.history
                  .where((value) => value.date == date)
                  .firstOrNull;
              final label = record == null
                  ? (future ? '待开始' : '待汇总')
                  : reportStatusLabel(record.state, record.reviewDecision);
              return ChoiceChip(
                selected: data.date == date,
                label: Text('Day ${index + 1} · $label'),
                tooltip: date.toString(),
                onSelected: future || controller.saving
                    ? null
                    : (_) => widget.onSelection(service.episode.id, date),
              );
            },
          ),
      ],
    );
  }
}
