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
              label: const Text('Back to today\'s follow-ups'),
            ),
          ),
          const SizedBox(height: 14),
          WorkbenchHeading(
            title: client?.displayName ?? 'Clinical follow-up',
            subtitle:
                'AI organizes client questions and answers for IBCLC review and feedback.',
            actions: [
              if (client != null)
                OutlinedButton(
                  onPressed: widget.onClient,
                  child: const Text('View client profile'),
                ),
              IconButton(
                tooltip: 'Refresh report',
                onPressed: controller.busy ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.busy)
            const LinearProgressIndicator(semanticsLabel: 'Syncing report'),
          if (controller.failure != null) ...[
            if (controller.failure!.code == 'ai_consent_required')
              const ReportSection(
                title: 'Waiting for AI consent',
                child: Text(
                  'The client must enable AI context consent for this service before a report can be read or generated.',
                ),
              )
            else if (controller.failure!.code == 'care_reports_unavailable')
              const ReportSection(
                title: 'AI report unavailable',
                child: Text(
                  'Report generation is not ready yet. Try again later.',
                ),
              ),
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          ],
          if (client != null && service != null) ...[
            ReportSection(
              title: 'Current service',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in client.services)
                    ChoiceChip(
                      label: Text(option.package.publicName),
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
                title: 'Waiting for case consent',
                child: Text(
                  'The client has not consented to case access for this service.',
                ),
              ),
            if (data != null) ...[
              ReportSection(
                title: service.episode.startsAt == null
                    ? 'Consultation preparation'
                    : '${service.package.durationDays}-day service period',
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
                      '${service.episode.totalSessions - service.episode.remainingSessions} of ${service.episode.totalSessions} consultations used${service.episode.endsAt == null ? '' : ' · ${dateInTimezone(service.episode.endsAt!, data.timezone)} ended'}',
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
                    ? 'Pre-consultation summary'
                    : '${data.date} · Daily follow-up',
                action: WorkbenchBadge(
                  reportStatusLabel(data.state, report?.review?.decision),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (report?.asOf != null)
                      Text(
                        'Information through ${dateInTimezone(report!.asOf!, data.timezone)} ${zonedClock(report.asOf!, data.timezone)} · ${data.timezone} · Version ${report.version}',
                        style: const TextStyle(
                          color: MomCozyColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (data.state != CareReportState.ready)
                      Text(switch (data.state) {
                        CareReportState.notGenerated =>
                          'No report has been generated for this day. You can summarize authorized service information.',
                        CareReportState.waitingForRecord =>
                          'No daily records or complete service conversations are available for this date. You can update the report after new records arrive.',
                        CareReportState.queued || CareReportState.running =>
                          'The report is being prepared and will update automatically when ready.',
                        CareReportState.failed =>
                          'Generation did not finish. Regenerate before reviewing.',
                        CareReportState.cancelled =>
                          'Sources or consent changed. Regenerate before reviewing.',
                        _ => 'Check consent for this service.',
                      }),
                    if (report != null && report.omittedCount > 0)
                      Text(
                        '${report.omittedCount} sources were omitted from this summary, so coverage is incomplete.',
                        style: const TextStyle(color: MomCozyColors.amber),
                      ),
                    if (data.state == CareReportState.ready)
                      const Text(
                        'AI content is for professional review. Confirmation or suggested changes will be saved as a clinical review record.',
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
                        child: Text(
                          'Assignment or consent has changed. Regenerate before reviewing.',
                        ),
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
                              ? 'Generate report'
                              : 'Update report',
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
                      title: 'AI summary',
                      child: ReportFindings(
                        report: report!,
                        items: report.content!.summary,
                        empty: 'No facts to summarize yet.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    ReportSection(
                      title: 'Client\'s own words',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Current mood',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          ReportFindings(
                            report: report,
                            items: report.content!.emotionalState,
                            empty: 'No clear mood statements yet.',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Communication preferences',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          ReportFindings(
                            report: report,
                            items: report.content!.communicationPreferences,
                            empty: 'No clear communication preferences yet.',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final right = ReportSection(
                  title: 'Clinical review',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReportFindings(
                        report: report,
                        items: report.content!.checks,
                        empty: 'No additional items to review.',
                      ),
                      if (report.content!.dataGaps.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Information gaps',
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
              title: 'Service conversations',
              child: ReportDialogueList(report: report!),
            ),
            const SizedBox(height: 18),
            ReportSection(
              title: 'Clinical review',
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
                                ? 'Confirmed: This report and its included responses were approved.'
                                : 'Feedback submitted: Changes suggested below.',
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
                            '${dateInTimezone(report.review!.createdAt, report.timezone)} ${zonedClock(report.review!.createdAt, report.timezone)} · Review version ${report.review!.version}',
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
                    'Confirm to approve the report, or provide specific feedback to suggest changes.',
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
                        child: const Text('Confirm responses'),
                      ),
                      FilledButton(
                        onPressed: controller.busy || !report.reviewable
                            ? null
                            : () => _feedback(report),
                        child: const Text('Suggest changes'),
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
                  ? (future ? 'Not started' : 'Not generated')
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
