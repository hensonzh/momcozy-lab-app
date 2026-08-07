import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/plan/presentation/plan_page.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  final now = DateTime(2026, 10, 22, 9, 41);

  setUpAll(loadMomCozyTestFonts);

  testWidgets('renders the supplied empty-plan structure without legacy UI', (
    tester,
  ) async {
    var createCount = 0;
    await _pumpPlanPage(
      tester,
      dashboard: PlanDashboard.empty(weekOf: now),
      now: now,
      onCreatePlan: () => createCount += 1,
    );

    await expectLater(
      find.byKey(const ValueKey('route-page-/plan')),
      matchesGoldenFile('../../goldens/plan/empty_mobile.png'),
    );

    expect(find.byKey(const ValueKey('plan-empty-state')), findsOneWidget);
    expect(find.text('My Plans'), findsOneWidget);
    expect(find.text('No Plans Yet'), findsOneWidget);
    expect(find.text('+ Create Your First Plan'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Cozymate 1 on 1'), findsOneWidget);

    await tester.tap(find.text('+ Create Your First Plan'));
    expect(createCount, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Postpartum Recovery'), findsOneWidget);
    expect(find.text('momcozy Smart Pump'), findsOneWidget);
    expect(find.text('Breast Health Check'), findsOneWidget);

    expect(find.text('日程'), findsNothing);
    expect(find.text('泌乳计划'), findsNothing);
    expect(find.text('今天还没有计划任务'), findsNothing);
    expect(find.text('Day'), findsNothing);
  });

  testWidgets('renders the supplied multi-category weekly plan structure', (
    tester,
  ) async {
    await _pumpPlanPage(
      tester,
      dashboard: _multiCategoryDashboard(now),
      now: now,
    );

    await expectLater(
      find.byKey(const ValueKey('route-page-/plan')),
      matchesGoldenFile('../../goldens/plan/multi_category_mobile.png'),
    );

    expect(
      find.byKey(const ValueKey('plan-multi-category-state')),
      findsOneWidget,
    );
    expect(find.text('My Plans'), findsOneWidget);
    expect(find.text('Lactation'), findsOneWidget);
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('Pelvic Floor'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('This Week'), findsNWidgets(2));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('3 of 5 sessions completed'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Monthly Calendar'), findsOneWidget);

    expect(find.text('日程'), findsNothing);
    expect(find.text('泌乳计划'), findsNothing);
    expect(find.text('吸奶补录'), findsNothing);
    expect(find.text('喂养记录'), findsNothing);
  });

  testWidgets('renders the supplied single-plan detail structure', (
    tester,
  ) async {
    await _pumpPlanPage(tester, dashboard: _singlePlanDashboard(now), now: now);

    await expectLater(
      find.byKey(const ValueKey('route-page-/plan')),
      matchesGoldenFile('../../goldens/plan/single_category_mobile.png'),
    );

    expect(
      find.byKey(const ValueKey('plan-single-category-state')),
      findsOneWidget,
    );
    expect(find.text('Breast Pumping Plan'), findsOneWidget);
    expect(find.text('Mid-Way Milestone'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('4/8'), findsOneWidget);
    expect(find.text("Today's Sessions"), findsOneWidget);
    expect(find.text('Session 1'), findsOneWidget);
    expect(find.text('Session 2'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Volume Progress'), findsOneWidget);
    expect(find.text("Today's Target"), findsOneWidget);
    expect(find.text('Weekly Target'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Plan Settings'), findsOneWidget);
    expect(find.text('Adjust with AI'), findsOneWidget);
    expect(find.text('Manual Edit'), findsOneWidget);

    expect(find.text('My Plans'), findsNothing);
    expect(find.text('日程'), findsNothing);
    expect(find.text('今天还没有计划任务'), findsNothing);
  });
}

Future<void> _pumpPlanPage(
  WidgetTester tester, {
  required PlanDashboard dashboard,
  required DateTime now,
  VoidCallback? onCreatePlan,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Quicksand'),
      home: PlanPage(
        repository: _FakePlanRepository(dashboard),
        now: () => now,
        onCreatePlan: onCreatePlan,
        onChat: () {},
        onStartSession: () {},
        onManualEdit: () {},
      ),
    ),
  );
  final context = tester.element(
    find.byKey(const ValueKey('route-page-/plan')),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/plan-cozymate-avatar.jpg'),
      context,
    ),
  );
  await tester.pumpAndSettle();
}

PlanDashboard _multiCategoryDashboard(DateTime now) {
  final plans = [
    const CarePlan(
      id: 'lactation',
      category: PlanCategory.lactation,
      title: 'Lactation',
      summary: 'Pumping plan',
    ),
    const CarePlan(
      id: 'yoga',
      category: PlanCategory.yoga,
      title: 'Yoga',
      summary: 'Recovery yoga',
    ),
    const CarePlan(
      id: 'pelvic',
      category: PlanCategory.pelvicFloor,
      title: 'Pelvic Floor',
      summary: 'Pelvic floor recovery',
    ),
  ];
  return PlanDashboard(
    weekOf: now,
    plans: plans,
    weeklyCompletedSessions: 3,
    weeklyTotalSessions: 5,
    sessions: [
      PlanSession(
        id: 'one',
        planId: 'lactation',
        title: 'Pumping: Express 20min',
        scheduledAt: DateTime(2026, 10, 22, 8),
        status: PlanSessionStatus.completed,
      ),
      PlanSession(
        id: 'two',
        planId: 'lactation',
        title: 'Pumping: Express 20min',
        scheduledAt: DateTime(2026, 10, 22, 11),
        status: PlanSessionStatus.next,
      ),
      PlanSession(
        id: 'three',
        planId: 'pelvic',
        title: 'Pelvic Floor: Evening Stretches 15min',
        scheduledAt: DateTime(2026, 10, 22, 16),
        status: PlanSessionStatus.upcoming,
      ),
    ],
  );
}

PlanDashboard _singlePlanDashboard(DateTime now) {
  const plan = CarePlan(
    id: 'lactation',
    category: PlanCategory.lactation,
    title: 'Breast Pumping Plan',
    summary: 'Five sessions every day',
    weekNumber: 4,
    totalWeeks: 8,
    sessionsPerDay: 5,
    dailyTargetVolumeMl: 600,
    todayVolumeMl: 473,
    weeklyTargetVolumeMl: 4200,
    weeklyVolumeMl: 2850,
  );
  return PlanDashboard(
    weekOf: now,
    plans: const [plan],
    sessions: [
      PlanSession(
        id: 'one',
        planId: plan.id,
        title: 'Session 1',
        valueLabel: '120 ml',
        scheduledAt: DateTime(2026, 10, 22, 8),
        status: PlanSessionStatus.completed,
      ),
      PlanSession(
        id: 'two',
        planId: plan.id,
        title: 'Session 2',
        scheduledAt: DateTime(2026, 10, 22, 11),
        status: PlanSessionStatus.next,
      ),
      PlanSession(
        id: 'three',
        planId: plan.id,
        title: 'Session 3',
        scheduledAt: DateTime(2026, 10, 22, 14),
        status: PlanSessionStatus.upcoming,
      ),
      PlanSession(
        id: 'four',
        planId: plan.id,
        title: 'Session 4',
        scheduledAt: DateTime(2026, 10, 22, 17),
        status: PlanSessionStatus.upcoming,
      ),
      PlanSession(
        id: 'five',
        planId: plan.id,
        title: 'Session 5',
        scheduledAt: DateTime(2026, 10, 22, 20),
        status: PlanSessionStatus.upcoming,
      ),
    ],
  );
}

class _FakePlanRepository implements PlanRepository {
  const _FakePlanRepository(this.dashboard);

  final PlanDashboard dashboard;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) async {
    return dashboard;
  }
}
