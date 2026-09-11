import '../shared/local_date.dart';
import 'workbench.dart';

final class WorkbenchCalendar {
  const WorkbenchCalendar({
    required this.weekStart,
    required this.timezone,
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final LocalDate weekStart;
  final String timezone;
  final List<WorkbenchAppointment> items;
  final int total, offset, limit;
  final DateTime serverTime;
}

abstract interface class WorkbenchCalendarRepository {
  Future<WorkbenchCalendar> calendar({LocalDate? date, int offset = 0});
}
