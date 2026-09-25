import 'package:flutter/material.dart';
import '../../../../domain/care/care_report.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/zoned_time.dart';
import '../application/report_presentation.dart';

class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

Future<void> showReportSource(
  BuildContext context,
  CareReport report,
  CareReportCitation citation,
) async {
  final source = report.sources
      .where((value) => value.id == citation.sourceId)
      .firstOrNull;
  if (source == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(reportSourceLabels[source.kind]!),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${dateInTimezone(source.recordedAt, report.timezone)} ${zonedClock(source.recordedAt, report.timezone)} · ${report.timezone}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Text(source.content),
                if (source.truncated)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('This source is long. Only an excerpt is shown here.'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class ReportFindings extends StatelessWidget {
  const ReportFindings({
    super.key,
    required this.report,
    required this.items,
    required this.empty,
  });
  final CareReport report;
  final List<CareReportFinding> items;
  final String empty;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? Text(
          empty,
          style: const TextStyle(
            color: MomCozyColors.mutedForeground,
            fontSize: 13,
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionArea(
                      child: Text(
                        items[index].text,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                    for (final citation in items[index].evidence)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
                        decoration: BoxDecoration(
                          color: MomCozyColors.muted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '“${citation.quote}”',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: MomCozyColors.mutedForeground,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  showReportSource(context, report, citation),
                              icon: const Icon(
                                Icons.description_outlined,
                                size: 14,
                              ),
                              label: const Text('View source'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
}

class ReportDialogueList extends StatelessWidget {
  const ReportDialogueList({super.key, required this.report});
  final CareReport report;
  @override
  Widget build(BuildContext context) => report.dialogues.isEmpty
      ? const Text(
          'No complete service conversations are available to share for this period.',
          style: TextStyle(color: MomCozyColors.mutedForeground),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < report.dialogues.length; index++)
              Container(
                margin: EdgeInsets.only(top: index == 0 ? 0 : 16),
                decoration: BoxDecoration(
                  border: Border.all(color: MomCozyColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client question ${(index + 1).toString().padLeft(2, '0')} · ${zonedClock(report.dialogues[index].questionAt, report.timezone)}',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectionArea(
                      child: Text(
                        report.dialogues[index].question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const Divider(height: 30),
                    const Text(
                      'AI response',
                      style: TextStyle(fontSize: 12, color: MomCozyColors.care),
                    ),
                    const SizedBox(height: 8),
                    SelectionArea(
                      child: Text(
                        report.dialogues[index].answer,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                    if (report.dialogues[index].truncated)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'This conversation is long. An excerpt from the original is shown.',
                          style: TextStyle(
                            fontSize: 12,
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
}
