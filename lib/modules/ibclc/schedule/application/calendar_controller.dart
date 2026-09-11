import 'package:flutter/foundation.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/ibclc/workbench_calendar.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../domain/shared/product_failure.dart';
import '../../../../shared/zoned_time.dart';

class WorkbenchCalendarController extends ChangeNotifier {
  WorkbenchCalendarController(this.repository);
  final WorkbenchCalendarRepository repository;
  LocalDate? selectedDate, weekStart;
  String? timezone;
  DateTime? serverTime;
  List<WorkbenchAppointment> items = [];
  ProductFailure? failure;
  bool loading = false, _disposed = false;
  int _generation = 0;
  LocalDate? get today => serverTime == null || timezone == null
      ? null
      : dateInTimezone(serverTime!, timezone!);
  List<WorkbenchAppointment> onDate(LocalDate date) {
    if (timezone == null) return [];
    final window = zonedDayWindow(date, timezone!);
    return items
        .where(
          (value) =>
              value.appointment.startsAt.isBefore(window.end) &&
              value.appointment.endsAt.isAfter(window.start),
        )
        .toList();
  }

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final collected = <String, WorkbenchAppointment>{};
      var offset = 0;
      WorkbenchCalendar? first;
      while (true) {
        final page = await repository.calendar(
          date: first?.weekStart ?? selectedDate,
          offset: offset,
        );
        if (_disposed || generation != _generation) return;
        first ??= page;
        if (page.weekStart != first.weekStart ||
            page.timezone != first.timezone ||
            page.offset != offset ||
            page.limit <= 0 ||
            (page.items.isEmpty && offset < page.total)) {
          throw const ProductFailure(
            ProductFailureKind.conflict,
            code: 'calendar_changed',
          );
        }
        for (final item in page.items) {
          collected[item.appointment.id] = item;
        }
        offset += page.limit;
        if (offset >= page.total) break;
      }
      weekStart = first.weekStart;
      timezone = first.timezone;
      serverTime = first.serverTime;
      selectedDate ??= today;
      items = collected.values.toList()
        ..sort(
          (a, b) => a.appointment.startsAt.compareTo(b.appointment.startsAt),
        );
    } catch (error) {
      if (_disposed || generation != _generation) return;
      items = [];
      weekStart = null;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> select(LocalDate date) {
    selectedDate = date;
    final start = weekStart;
    if (start != null &&
        date.compareTo(start) >= 0 &&
        date.compareTo(start.addDays(7)) < 0 &&
        failure == null) {
      notifyListeners();
      return Future.value();
    }
    items = [];
    weekStart = null;
    return load();
  }

  Future<void> currentWeek() {
    selectedDate = null;
    items = [];
    weekStart = null;
    return load();
  }

  Future<void> shiftWeek(int direction) => selectedDate == null
      ? Future.value()
      : select(selectedDate!.addDays(direction * 7));
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
