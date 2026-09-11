import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench_calendar.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/ibclc/schedule/application/calendar_controller.dart';
import 'package:momcozy_flutter_app/modules/ibclc/schedule/application/calendar_timeline.dart';
import 'package:momcozy_flutter_app/services/ibclc/workbench_codec.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import 'workbench_test_support.dart';

WorkbenchAppointment event(String id, String start, String end) {
  final json = Map<String, Object?>.from(
    (workbenchFixture('appointments')['items'] as List).single as Map,
  );
  json['appointment'] = Map<String, Object?>.from(json['appointment'] as Map)
    ..['id'] = id
    ..['starts_at'] = start
    ..['ends_at'] = end;
  return readWorkbenchAppointments({
    ...workbenchFixture('appointments'),
    'items': [json],
  }).items.single;
}

WorkbenchCalendar page({
  List<WorkbenchAppointment> items = const [],
  int total = 0,
  int offset = 0,
  int limit = 100,
  LocalDate? start,
}) => WorkbenchCalendar(
  weekStart: start ?? LocalDate(2026, 9, 7),
  timezone: 'America/Los_Angeles',
  items: items,
  total: total,
  offset: offset,
  limit: limit,
  serverTime: DateTime.utc(2026, 9, 10, 15, 55),
);

class CalendarRepository implements WorkbenchCalendarRepository {
  CalendarRepository(this.read);
  final Future<WorkbenchCalendar> Function(LocalDate?, int) read;
  @override
  Future<WorkbenchCalendar> calendar({LocalDate? date, int offset = 0}) =>
      read(date, offset);
}

void main() {
  test(
    'calendar joins all pages and pins the selected week after the first response',
    () async {
      final a = event('a', '2026-09-10T16:00:00Z', '2026-09-10T17:00:00Z');
      final b = event('b', '2026-09-11T06:30:00Z', '2026-09-11T07:30:00Z');
      final calls = <({LocalDate? date, int offset})>[];
      final controller = WorkbenchCalendarController(
        CalendarRepository((date, offset) async {
          calls.add((date: date, offset: offset));
          return page(
            items: offset == 0 ? [a] : [b],
            total: 2,
            offset: offset,
            limit: 1,
          );
        }),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(calls, [
        (date: null, offset: 0),
        (date: LocalDate(2026, 9, 7), offset: 1),
      ]);
      expect(controller.items, [a, b]);
      expect(controller.onDate(LocalDate(2026, 9, 10)), [a, b]);
      expect(controller.onDate(LocalDate(2026, 9, 11)), [b]);
      await controller.select(LocalDate(2026, 9, 11));
      expect(calls.length, 2);
    },
  );

  test(
    'late week and incomplete refresh responses never restore a stale calendar',
    () async {
      final old = Completer<WorkbenchCalendar>();
      final a = event('a', '2026-09-17T16:00:00Z', '2026-09-17T17:00:00Z');
      var count = 0;
      final controller = WorkbenchCalendarController(
        CalendarRepository((date, offset) async {
          count++;
          if (count == 1) return old.future;
          if (count == 2) {
            return page(start: LocalDate(2026, 9, 14), items: [a], total: 1);
          }
          if (count == 3) {
            return page(
              start: LocalDate(2026, 9, 14),
              items: [a],
              total: 2,
              limit: 1,
            );
          }
          throw const ProductFailure(ProductFailureKind.forbidden);
        }),
      );
      addTearDown(controller.dispose);
      final previous = controller.load();
      await controller.select(LocalDate(2026, 9, 17));
      old.complete(page());
      await previous;
      expect(controller.items, [a]);
      expect(controller.weekStart, LocalDate(2026, 9, 14));
      await controller.load();
      expect(controller.failure?.kind, ProductFailureKind.forbidden);
      expect(controller.items, isEmpty);
      expect(controller.weekStart, isNull);
    },
  );

  test(
    'timeline splits midnight, uses half-open boundaries, and includes late appointments',
    () {
      final midnight = event(
        'a',
        '2026-09-08T06:30:00Z',
        '2026-09-08T07:30:00Z',
      );
      final boundary = event(
        'b',
        '2026-09-09T06:00:00Z',
        '2026-09-09T07:00:00Z',
      );
      final timeline = CalendarTimeline(
        appointments: [midnight, boundary],
        weekStart: LocalDate(2026, 9, 7),
        timezone: 'America/Los_Angeles',
      );
      expect(timeline.startHour, 0);
      expect(timeline.endHour, 24);
      expect(timeline.onDay(LocalDate(2026, 9, 7)).single.startMinute, 1410);
      expect(timeline.onDay(LocalDate(2026, 9, 7)).single.endMinute, 1440);
      expect(timeline.onDay(LocalDate(2026, 9, 8)).first.endMinute, 30);
      expect(timeline.onDay(LocalDate(2026, 9, 9)), isEmpty);
    },
  );

  test(
    'clock changes use local date windows and distinguish repeated clock times',
    () {
      final spring = zonedDayWindow(
        LocalDate(2026, 3, 8),
        'America/Los_Angeles',
      );
      final fall = zonedDayWindow(
        LocalDate(2026, 11, 1),
        'America/Los_Angeles',
      );
      expect(spring.end.difference(spring.start).inHours, 23);
      expect(fall.end.difference(fall.start).inHours, 25);
      final repeated = event(
        'a',
        '2026-11-01T08:30:00Z',
        '2026-11-01T09:30:00Z',
      );
      final timeline = CalendarTimeline(
        appointments: [repeated],
        weekStart: LocalDate(2026, 10, 26),
        timezone: 'America/Los_Angeles',
      );
      expect(timeline.clockChangeWeek, isTrue);
      expect(timeline.onDay(LocalDate(2026, 11, 1)).single.item, repeated);
      expect(
        zonedRange(
          repeated.appointment.startsAt,
          repeated.appointment.endsAt,
          timeline.timezone,
        ),
        '01:30 PDT – 01:30 PST',
      );
    },
  );
}
