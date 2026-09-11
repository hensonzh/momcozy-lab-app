import '../../../../domain/care/care_report.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/zoned_time.dart';

const reportStateLabels = <CareReportState, String>{
  CareReportState.notGenerated: '待汇总',
  CareReportState.waitingForRecord: '等待用户记录',
  CareReportState.queued: '等待生成',
  CareReportState.running: '正在生成',
  CareReportState.ready: '待复核',
  CareReportState.failed: '生成失败',
  CareReportState.cancelled: '需要重新生成',
  CareReportState.caseConsentRequired: '等待病例授权',
  CareReportState.aiConsentRequired: '等待 AI 授权',
};
const reportSourceLabels = <CareReportSourceKind, String>{
  CareReportSourceKind.dialogue: '服务对话',
  CareReportSourceKind.intake: '咨询前资料',
  CareReportSourceKind.motherDiary: '妈妈日记',
  CareReportSourceKind.lactation: '泌乳记录',
  CareReportSourceKind.carePlan: '已发布方案',
  CareReportSourceKind.babyRecord: '宝宝记录',
};
String reportStatusLabel(
  CareReportState state,
  CareReportReviewDecision? review,
) => review == null
    ? reportStateLabels[state]!
    : review == CareReportReviewDecision.confirmed
    ? '已确认'
    : '已反馈';
String serviceDayLabel(
  ClientCareService service,
  LocalDate day,
  String timezone,
) {
  final start = service.episode.startsAt;
  if (start == null) return '咨询准备阶段';
  final number = (day.daysSince(dateInTimezone(start, timezone)) + 1).clamp(
    1,
    service.package.durationDays,
  );
  return '第 $number/${service.package.durationDays} 天';
}
