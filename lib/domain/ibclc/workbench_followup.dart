import '../care/care_report.dart';
import '../shared/local_date.dart';
import 'workbench.dart';

enum WorkbenchFollowupFilter { all, pending, completed }

final class FollowupCareService {
  const FollowupCareService({
    required this.service,
    required this.aiConsent,
    required this.purpose,
    required this.reportState,
    this.reportId,
    this.reviewDecision,
  });
  final ClientCareService service;
  final bool aiConsent;
  final CareReportPurpose purpose;
  final CareReportState reportState;
  final String? reportId;
  final CareReportReviewDecision? reviewDecision;
}

final class WorkbenchFollowupClient {
  const WorkbenchFollowupClient({
    required this.patientRef,
    required this.services,
    required this.completed,
    this.name,
  });
  final String patientRef;
  final String? name;
  final List<FollowupCareService> services;
  final bool completed;
  String get displayName => services.any((item) => item.service.caseConsent)
      ? (name?.trim().isNotEmpty == true ? name! : '未填写姓名')
      : '待授权用户';
}

final class WorkbenchFollowups {
  const WorkbenchFollowups({
    required this.date,
    required this.timezone,
    required this.items,
    required this.total,
    required this.allCount,
    required this.pendingCount,
    required this.completedCount,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final LocalDate date;
  final String timezone;
  final List<WorkbenchFollowupClient> items;
  final int total, allCount, pendingCount, completedCount, offset, limit;
  final DateTime serverTime;
}

abstract interface class WorkbenchFollowupsRepository {
  Future<WorkbenchFollowups> followups({
    String query = '',
    WorkbenchFollowupFilter filter = WorkbenchFollowupFilter.all,
    int offset = 0,
  });
}
