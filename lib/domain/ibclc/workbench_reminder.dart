import '../care/service_event.dart';
import '../shared/local_date.dart';

final class WorkbenchReminder {
  const WorkbenchReminder({
    required this.event,
    required this.patientRef,
    required this.packageName,
    this.patientName,
    this.startsAt,
    this.timezone,
    this.readAt,
    this.reportDate,
  });
  final CareServiceEvent event;
  final String patientRef, packageName;
  final String? patientName, timezone;
  final DateTime? startsAt, readAt;
  final LocalDate? reportDate;
  String get displayName => patientName?.trim().isNotEmpty == true
      ? patientName!
      : '客户 ${patientRef.substring(0, 8)}';
}

final class WorkbenchReminders {
  const WorkbenchReminders({
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final List<WorkbenchReminder> items;
  final int total, unreadCount, offset, limit;
  final DateTime serverTime;
}

abstract interface class WorkbenchRemindersRepository {
  Future<WorkbenchReminders> reminders({int offset = 0});
  Future<void> readReminder(String eventId);
}
