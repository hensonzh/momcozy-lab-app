import '../../domain/ibclc/workbench_followup.dart';
import '../../domain/shared/local_date.dart';
import '../reports/report_codec.dart';
import '../shared/json_value.dart';
import 'workbench_codec.dart';

const followupFilterWire = EnumWire<WorkbenchFollowupFilter>({
  WorkbenchFollowupFilter.all: 'all',
  WorkbenchFollowupFilter.pending: 'pending',
  WorkbenchFollowupFilter.completed: 'completed',
});
WorkbenchFollowups readFollowups(Map<String, Object?> json) =>
    WorkbenchFollowups(
      date: LocalDate.parse(jsonString(json['date'])),
      timezone: jsonString(json['timezone']),
      items: jsonList(json['items'], (item) {
        final status = followupFilterWire.read(item['status']);
        if (status == null || status == WorkbenchFollowupFilter.all) {
          throw const FormatException('Expected a client follow-up status.');
        }
        return WorkbenchFollowupClient(
          patientRef: jsonString(item['patient_ref']),
          name: item['name'] as String?,
          completed: status == WorkbenchFollowupFilter.completed,
          services: jsonList(
            item['services'],
            (service) => FollowupCareService(
              service: readClientService(jsonObject(service['service'])),
              aiConsent: jsonBool(service['ai_consent']),
              purpose: reportPurposeWire.read(service['purpose'])!,
              reportState: reportStateWire.read(service['report_status'])!,
              reportId: service['report_id'] as String?,
              reviewDecision: reportReviewWire.read(service['review_decision']),
            ),
          ),
        );
      }),
      total: jsonInt(json['total']),
      allCount: jsonInt(json['all_count']),
      pendingCount: jsonInt(json['pending_count']),
      completedCount: jsonInt(json['completed_count']),
      offset: jsonInt(json['offset']),
      limit: jsonInt(json['limit']),
      serverTime: jsonInstant(json['server_time']),
    );
