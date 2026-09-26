import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/schedule/application/schedule_controller.dart';
import 'package:momcozy_flutter_app/modules/schedule/domain/schedule.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_calendar.dart';

void main() {
  testWidgets('week and month arrows use the same size and still shift', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = ScheduleState(
      phase: SchedulePhase.ready,
      month: LocalDate(2026, 9, 1),
      selected: LocalDate(2026, 9, 25),
      page: SchedulePageData(
        personal: const [],
        serverTime: DateTime(2026, 9, 25),
        hasMore: false,
      ),
    );
    final shifts = <int>[];
    Widget calendar({required bool expanded}) => MaterialApp(
      home: Scaffold(
        body: ScheduleCalendar(
          state: state,
          expanded: expanded,
          onSelect: (_) {},
          onShift: shifts.add,
          onToday: () {},
        ),
      ),
    );

    await tester.pumpWidget(calendar(expanded: false));
    final weekLeft = tester.widget<Text>(find.text('‹')).style;
    final weekRight = tester.widget<Text>(find.text('›')).style;
    expect(weekLeft?.fontSize, 24);
    expect(weekRight?.fontSize, 24);
    await tester.tap(find.byTooltip('Previous week'));
    expect(shifts, [-1]);

    await tester.pumpWidget(calendar(expanded: true));
    expect(tester.widget<Text>(find.text('‹')).style, weekLeft);
    expect(tester.widget<Text>(find.text('›')).style, weekRight);
    await tester.tap(find.byTooltip('Next month'));
    expect(shifts, [-1, 1]);
  });
}
