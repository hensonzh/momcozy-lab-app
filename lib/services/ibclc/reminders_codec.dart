import '../../domain/ibclc/workbench_reminder.dart';
import '../../domain/shared/local_date.dart';
import '../care/service_event_codec.dart';
import '../shared/json_value.dart';

WorkbenchReminder readReminder(Map<String, Object?> json) => WorkbenchReminder(
  event: readServiceEvent(json),
  patientRef: jsonString(json['patient_ref']),
  patientName: json['patient_name'] as String?,
  packageName: jsonString(json['package_name']),
  timezone: json['timezone'] as String?,
  startsAt: json['starts_at'] == null ? null : jsonInstant(json['starts_at']),
  readAt: json['read_at'] == null ? null : jsonInstant(json['read_at']),
  reportDate: json['report_date'] == null
      ? null
      : LocalDate.parse(jsonString(json['report_date'])),
);
WorkbenchReminders readReminders(Map<String, Object?> json) =>
    WorkbenchReminders(
      items: jsonList(json['items'], readReminder),
      total: jsonInt(json['total']),
      unreadCount: jsonInt(json['unread_count']),
      offset: jsonInt(json['offset']),
      limit: jsonInt(json['limit']),
      serverTime: jsonInstant(json['server_time']),
    );
