import '../../../../domain/care/care_report.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/zoned_time.dart';

const reportStateLabels = <CareReportState, String>{
  CareReportState.notGenerated: 'Not generated',
  CareReportState.waitingForRecord: 'Waiting for client records',
  CareReportState.queued: 'Queued',
  CareReportState.running: 'Generating',
  CareReportState.ready: 'Needs review',
  CareReportState.failed: 'Generation failed',
  CareReportState.cancelled: 'Regenerate required',
  CareReportState.caseConsentRequired: 'Waiting for case consent',
  CareReportState.aiConsentRequired: 'Waiting for AI consent',
};
const reportSourceLabels = <CareReportSourceKind, String>{
  CareReportSourceKind.dialogue: 'Service conversation',
  CareReportSourceKind.intake: 'Consultation intake',
  CareReportSourceKind.lactation: 'Lactation records',
  CareReportSourceKind.carePlan: 'Published plan',
  CareReportSourceKind.babyRecord: 'Baby records',
};
String reportStatusLabel(
  CareReportState state,
  CareReportReviewDecision? review,
) => review == null
    ? reportStateLabels[state]!
    : review == CareReportReviewDecision.confirmed
    ? 'Confirmed'
    : 'Feedback provided';
String serviceDayLabel(
  ClientCareService service,
  LocalDate day,
  String timezone,
) {
  final start = service.episode.startsAt;
  if (start == null) return 'Consultation preparation';
  final number = (day.daysSince(dateInTimezone(start, timezone)) + 1).clamp(
    1,
    service.package.durationDays,
  );
  return 'Day $number of ${service.package.durationDays}';
}
