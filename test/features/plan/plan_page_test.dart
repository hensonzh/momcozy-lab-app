import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/plan/presentation/plan_page.dart';

import '../../support/golden_cases.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  final now = DateTime(2024, 10, 22, 9, 41);
  final emptyNow = DateTime(2025, 10, 14, 9, 41);

  setUpAll(loadMomCozyPlanTestFonts);

  testWidgets('shows the Plan chrome on the first frame while data loads', (
    tester,
  ) async {
    final repository = _DeferredPlanRepository();
    addTearDown(repository.completeIfPending);

    await tester.pumpWidget(
      MaterialApp(
        home: PlanPage(repository: repository, now: () => emptyNow),
      ),
    );

    expect(repository.fetchCount, 1);
    expect(find.byKey(const ValueKey('route-page-/plan')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-loading-view')), findsOneWidget);
    expect(find.text('My Plans'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repository.complete(PlanDashboard.empty(weekOf: emptyNow));
    await tester.pump();

    expect(find.byKey(const ValueKey('plan-loading-view')), findsNothing);
    expect(find.text('No Plans Yet'), findsOneWidget);
  });

  testWidgets('shows cached Plan content while it refreshes in background', (
    tester,
  ) async {
    final cached = PlanDashboard.empty(weekOf: emptyNow);
    final repository = _CachedDeferredPlanRepository(cached);
    addTearDown(repository.completeIfPending);

    await tester.pumpWidget(
      MaterialApp(
        home: PlanPage(repository: repository, now: () => emptyNow),
      ),
    );

    expect(repository.fetchCount, 1);
    expect(find.byKey(const ValueKey('plan-loading-view')), findsNothing);
    expect(find.text('No Plans Yet'), findsOneWidget);
  });

  goldenTest('renders the supplied empty-plan structure without legacy UI', (
    tester,
  ) async {
    var createCount = 0;
    var calendarCount = 0;
    var allPlansCount = 0;
    var pumpCount = 0;
    var chatCount = 0;
    await _pumpPlanPage(
      tester,
      dashboard: PlanDashboard.empty(weekOf: emptyNow),
      now: emptyNow,
      onCreatePlan: () => createCount += 1,
      onOpenCalendar: () => calendarCount += 1,
      onOpenAllPlans: () => allPlansCount += 1,
      onStartPump: () => pumpCount += 1,
      onChat: () => chatCount += 1,
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

    final pageTitleStyle = _renderedTextStyle(tester, find.text('My Plans'));
    expect(pageTitleStyle.fontFamily, 'Rubik');
    expect(pageTitleStyle.fontSize, 24);
    expect(pageTitleStyle.fontWeight, FontWeight.w700);
    expect(pageTitleStyle.height, 1.2);

    final heroTitleStyle = _renderedTextStyle(
      tester,
      find.text('No Plans Yet'),
    );
    expect(heroTitleStyle.fontFamily, 'Figtree');
    expect(heroTitleStyle.fontSize, 24);
    expect(heroTitleStyle.fontWeight, FontWeight.w700);
    expect(heroTitleStyle.height, 1.3);

    final bodyStyle = _renderedTextStyle(
      tester,
      find.textContaining('Create a personalized recovery plan'),
    );
    expect(bodyStyle.fontFamily, 'Figtree');
    expect(bodyStyle.fontSize, 14);
    expect(bodyStyle.fontWeight, FontWeight.w400);
    expect(bodyStyle.height, 1.5);

    expect(tester.getTopLeft(find.text('My Plans')).dx, closeTo(19, 0.6));
    final titleRect = tester.getRect(find.text('My Plans'));
    final calendarRect = tester.getRect(
      find.byKey(const ValueKey('plan-header-calendar')),
    );
    expect(calendarRect.left - titleRect.right, closeTo(16, 0.6));
    expect(
      tester.getCenter(find.byKey(const ValueKey('plan-header-all-plans'))).dx,
      closeTo(354, 0.6),
    );

    await _pumpPlanPage(
      tester,
      dashboard: PlanDashboard.empty(weekOf: emptyNow),
      now: emptyNow,
      onCreatePlan: () => createCount += 1,
      onOpenCalendar: () => calendarCount += 1,
      onOpenAllPlans: () => allPlansCount += 1,
      onStartPump: () => pumpCount += 1,
      onChat: () => chatCount += 1,
      viewportSize: const Size(390, 1140),
    );
    await expectLater(
      find.byKey(const ValueKey('route-page-/plan')),
      matchesGoldenFile('../../goldens/plan/empty_full_mobile.png'),
    );

    _expectRect(
      tester,
      const ValueKey('plan-header'),
      const Rect.fromLTWH(0, 22, 390, 48),
    );
    _expectRect(
      tester,
      const ValueKey('plan-empty-week'),
      const Rect.fromLTWH(18, 92, 354, 51),
    );
    _expectRect(
      tester,
      const ValueKey('plan-empty-illustration'),
      const Rect.fromLTWH(18, 187, 354, 140),
    );
    _expectRect(
      tester,
      const ValueKey('plan-create-first-plan'),
      const Rect.fromLTWH(18, 458, 354, 48),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-service-header'),
      const Rect.fromLTWH(18, 519, 354, 104),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-service-recovery'),
      const Rect.fromLTWH(18, 620, 354, 125),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-service-pump'),
      const Rect.fromLTWH(18, 759, 354, 125),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-service-health'),
      const Rect.fromLTWH(18, 898, 354, 111),
      tolerance: 1,
    );
    await tester.tap(find.text('+ Create Your First Plan'));
    expect(createCount, 1);

    await tester.tap(find.byKey(const ValueKey('plan-header-calendar')));
    await tester.tap(find.byKey(const ValueKey('plan-header-all-plans')));
    expect(calendarCount, 1);
    expect(allPlansCount, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Postpartum Recovery'), findsOneWidget);
    expect(find.text('momcozy Smart Pump'), findsOneWidget);
    expect(find.text('Breast Health Check'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-service-recovery')));
    await tester.tap(find.byKey(const ValueKey('plan-service-pump')));
    await tester.tap(find.byKey(const ValueKey('plan-service-health')));
    expect(createCount, 2);
    expect(pumpCount, 1);
    expect(chatCount, 1);

    expect(find.text('日程'), findsNothing);
    expect(find.text('泌乳计划'), findsNothing);
    expect(find.text('今天还没有计划任务'), findsNothing);
    expect(find.text('Day'), findsNothing);
  });

  testWidgets('service cards use concise CTA labels without duplicate arrows', (
    tester,
  ) async {
    await _pumpPlanPage(
      tester,
      dashboard: PlanDashboard.empty(weekOf: emptyNow),
      now: emptyNow,
      viewportSize: const Size(390, 1140),
    );

    expect(find.text('Start guide'), findsOneWidget);
    expect(find.text('Check now'), findsNWidgets(2));
    expect(find.text('Start guide →'), findsNothing);
    expect(find.text('Check now →'), findsNothing);
  });

  testWidgets('service header keeps only a right-aligned Cozymate avatar', (
    tester,
  ) async {
    await _pumpPlanPage(
      tester,
      dashboard: PlanDashboard.empty(weekOf: emptyNow),
      now: emptyNow,
      viewportSize: const Size(390, 1140),
    );

    expect(find.text('Chat'), findsNothing);
    expect(find.text('Chat AI'), findsNothing);
    expect(find.byKey(const ValueKey('plan-cozymate-assistant')), findsNothing);
    final serviceHeader = tester.getRect(
      find.byKey(const ValueKey('plan-service-header')),
    );
    final avatar = tester.getRect(
      find.byKey(const ValueKey('plan-service-avatar')),
    );
    expect(avatar.right, closeTo(serviceHeader.right, 0.6));
  });

  testWidgets('a single active plan keeps a reversible My Plans overview', (
    tester,
  ) async {
    await _pumpPlanPage(tester, dashboard: _singlePlanDashboard(now), now: now);

    expect(
      find.byKey(const ValueKey('plan-multi-category-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-single-category-state')),
      findsNothing,
    );
    expect(find.text('My Plans'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-single-category-state')),
      findsOneWidget,
    );
    expect(find.text('My Plans'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-single-back')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-multi-category-state')),
      findsOneWidget,
    );
    expect(find.text('My Plans'), findsOneWidget);
  });

  testWidgets('the selected plan owns the visible sessions and progress', (
    tester,
  ) async {
    await _pumpPlanPage(tester, dashboard: _mixedPlanDashboard(now), now: now);

    expect(find.byKey(const ValueKey('plan-session-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-session-two')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-session-three')), findsNothing);
    expect(find.byKey(const ValueKey('plan-week-summary')), findsOneWidget);

    await tester.tap(find.text('Pelvic Floor'));
    await tester.pump();

    expect(find.byKey(const ValueKey('plan-session-one')), findsNothing);
    expect(find.byKey(const ValueKey('plan-session-two')), findsNothing);
    expect(find.byKey(const ValueKey('plan-session-three')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-week-summary')), findsNothing);
  });

  testWidgets('schedule headings describe the selected date truthfully', (
    tester,
  ) async {
    final repository = _RecordingPlanRepository(_multiCategoryDashboard(now));
    await _pumpPlanPage(
      tester,
      dashboard: repository.dashboard,
      repository: repository,
      now: now,
    );

    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-week-day-2024-10-23')));
    await tester.pumpAndSettle();

    expect(find.text('Wed, Oct 23'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  goldenTest('a future generated plan is shown as upcoming, not day one', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 10);
    final dashboard = _upcomingPlanDashboard(today);

    await _pumpPlanPage(tester, dashboard: dashboard, now: today);

    await expectLater(
      find.byKey(const ValueKey('route-page-/plan')),
      matchesGoldenFile('../../goldens/plan/generated_upcoming_mobile.png'),
    );

    expect(
      find.byKey(const ValueKey('plan-multi-category-state')),
      findsOneWidget,
    );
    expect(find.text('15-Day Supply Plan'), findsOneWidget);
    expect(find.text('Starts Aug 11'), findsOneWidget);
    expect(find.text('Day 1/15'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pump();

    expect(find.text('Starts Aug 11'), findsWidgets);
    expect(find.text('Day 1/15'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-single-back')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-jump-to-start')));
    await tester.pumpAndSettle();

    expect(find.text('Tue, Aug 11'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets(
    'generated plan overview keeps the week range beside Select Day',
    (tester) async {
      final today = DateTime(2026, 8, 19);
      final repository = _RecordingPlanRepository(
        _upcomingPlanDashboard(today),
      );
      await _pumpPlanPage(
        tester,
        dashboard: repository.dashboard,
        repository: repository,
        now: today,
      );

      expect(find.text('15-Day Supply Plan'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-period-day-selected')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('plan-period-week')), findsNothing);
      expect(find.text('Week'), findsNothing);

      final selectDay = tester.getRect(find.text('Select Day'));
      final weekRange = tester.getRect(
        find.byKey(const ValueKey('plan-week-range')),
      );
      expect(weekRange.center.dy, closeTo(selectDay.center.dy, 0.6));
      expect(weekRange.right, closeTo(372, 0.6));
      expect(find.text('Aug 17 - Aug 23'), findsOneWidget);

      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(repository.requestedDays.last, DateTime(2026, 8, 26));
      expect(find.text('Aug 24 - Aug 30'), findsOneWidget);
    },
  );

  testWidgets(
    'plan details remove the duplicate menu and align edit to the right',
    (tester) async {
      final today = DateTime(2026, 8, 19);
      await _pumpPlanPage(
        tester,
        dashboard: _upcomingPlanDashboard(today),
        now: today,
      );
      final overviewActionRight = tester
          .getRect(find.byKey(const ValueKey('plan-header-all-plans')))
          .right;

      await tester.tap(find.byKey(const ValueKey('plan-open-details')));
      await tester.pumpAndSettle();

      expect(find.text('15-Day Supply Plan'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-single-all-plans')), findsNothing);
      final edit = tester.getRect(
        find.byKey(const ValueKey('plan-single-edit')),
      );
      expect(edit.right, closeTo(overviewActionRight, 0.6));
    },
  );

  goldenTest('renders the supplied multi-category daily plan structure', (
    tester,
  ) async {
    PlanSession? startedSession;
    await _pumpPlanPage(
      tester,
      dashboard: _multiCategoryDashboard(now),
      now: now,
      onStartSession: (session) => startedSession = session,
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
    expect(find.byKey(const ValueKey('plan-period-week')), findsNothing);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Select Day'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-day-dot-2024-10-22')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-day-dot-2024-10-21')), findsNothing);
    await tester.tap(find.text('Start'));
    expect(startedSession?.id, 'two');
    expect(startedSession?.kind, PlanSessionKind.pumping);

    expect(
      find.byKey(const ValueKey('plan-period-day-selected')),
      findsOneWidget,
    );
    _expectRect(
      tester,
      const ValueKey('plan-header'),
      const Rect.fromLTWH(0, 18, 390, 48),
    );
    _expectRect(
      tester,
      const ValueKey('plan-category-tabs'),
      const Rect.fromLTWH(18, 74, 354, 36),
    );
    _expectRect(
      tester,
      const ValueKey('plan-period-selector'),
      const Rect.fromLTWH(18, 122, 354, 38),
    );
    await tester.tap(find.byKey(const ValueKey('plan-period-month')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('plan-period-month-selected')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('3 of 5 sessions completed'), findsNothing);
    expect(find.byKey(const ValueKey('plan-monthly-calendar')), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-period-day')));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('3 of 5 sessions completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-monthly-calendar')), findsNothing);

    expect(find.text('日程'), findsNothing);
    expect(find.text('泌乳计划'), findsNothing);
    expect(find.text('吸奶补录'), findsNothing);
    expect(find.text('喂养记录'), findsNothing);
  });

  testWidgets(
    'updates a task by stable id through the authoritative state API',
    (tester) async {
      final repository = _EditablePlanRepository(_multiCategoryDashboard(now));
      await _pumpPlanPage(
        tester,
        dashboard: repository.dashboard,
        repository: repository,
        now: now,
        viewportSize: const Size(360, 800),
      );

      await tester.tap(find.byKey(const ValueKey('plan-task-state-two')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();

      expect(repository.updatedStateSessionId, 'two');
      expect(repository.updatedState, PlanTaskState.completed);
      expect(find.byKey(const ValueKey('plan-task-state-two')), findsNothing);
    },
  );

  testWidgets('multi-category period and plan details change real content', (
    tester,
  ) async {
    await _pumpPlanPage(
      tester,
      dashboard: _multiCategoryDashboard(now),
      now: now,
    );

    expect(find.byKey(const ValueKey('plan-day-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-week-summary')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-period-month')));
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-month-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-monthly-calendar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-period-day')));
    await tester.pump();
    await tester.tap(find.text('Yoga'));
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-week-summary')), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-no-sessions-selected-day')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('plan-single-category-state')),
      findsOneWidget,
    );
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('Recovery yoga'), findsOneWidget);
  });

  testWidgets('Plan header opens the default calendar and all-plans flows', (
    tester,
  ) async {
    await _pumpPlanPage(
      tester,
      dashboard: _multiCategoryDashboard(now),
      now: now,
    );

    await tester.tap(find.byKey(const ValueKey('plan-header-calendar')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('plan-header-all-plans')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-all-plans-sheet')), findsOneWidget);
    expect(find.text('All Plans'), findsOneWidget);
    expect(find.text('Recovery yoga'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-all-plans-yoga')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-all-plans-sheet')), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-single-category-state')),
      findsOneWidget,
    );
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('Recovery yoga'), findsOneWidget);
  });

  testWidgets('day and month date cells reload the selected Plan day', (
    tester,
  ) async {
    final repository = _RecordingPlanRepository(_multiCategoryDashboard(now));
    await _pumpPlanPage(
      tester,
      dashboard: repository.dashboard,
      repository: repository,
      now: now,
    );

    await tester.tap(find.byKey(const ValueKey('plan-week-day-2024-10-23')));
    await tester.pumpAndSettle();
    expect(repository.requestedDays.last, DateTime(2024, 10, 23));
    expect(
      find.byKey(const ValueKey('plan-no-sessions-selected-day')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('plan-period-month')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-month-day-2024-10-25')));
    await tester.pumpAndSettle();
    expect(repository.requestedDays.last, DateTime(2024, 10, 25));
    expect(repository.requestedDays, hasLength(3));
    expect(
      find.byKey(const ValueKey('plan-period-month-selected')),
      findsOneWidget,
    );
  });

  testWidgets('calendar selection reloads the chosen Plan day', (tester) async {
    final repository = _RecordingPlanRepository(_multiCategoryDashboard(now));
    await _pumpPlanPage(
      tester,
      dashboard: repository.dashboard,
      repository: repository,
      now: now,
    );

    await tester.tap(find.byKey(const ValueKey('plan-header-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('23'),
      ),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repository.requestedDays.last, DateTime(2024, 10, 23));
  });

  testWidgets('system back returns from plan details to the overview', (
    tester,
  ) async {
    await _pumpPlanPage(tester, dashboard: _singlePlanDashboard(now), now: now);

    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('plan-single-category-state')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-multi-category-state')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-all-plans-sheet')), findsNothing);
    expect(find.text('My Plans'), findsOneWidget);
  });

  testWidgets('manual edit persists a session title and time', (tester) async {
    final repository = _EditablePlanRepository(_singlePlanDashboard(now));
    await _pumpPlanPage(
      tester,
      dashboard: repository.dashboard,
      repository: repository,
      now: now,
    );

    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual Edit'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-manual-edit-sheet')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('plan-manual-edit-title')),
      'Updated Session 2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('plan-manual-edit-time')),
      '09:15',
    );
    await tester.tap(find.byKey(const ValueKey('plan-manual-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.updatedSessionId, 'two');
    expect(repository.updatedTitle, 'Updated Session 2');
    expect(repository.updatedAt, DateTime(2024, 10, 22, 9, 15));
    expect(find.byKey(const ValueKey('plan-manual-edit-sheet')), findsNothing);
  });

  goldenTest('renders the supplied single-plan detail structure', (
    tester,
  ) async {
    var backCount = 0;
    var editCount = 0;
    var startCount = 0;
    await _pumpPlanPage(
      tester,
      dashboard: _singlePlanDashboard(now),
      now: now,
      onBackToPlans: () => backCount += 1,
      onStartSession: (_) => startCount += 1,
      onManualEdit: () => editCount += 1,
    );
    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pump();

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
    expect(
      find.byKey(const ValueKey('plan-milestone-selected-2024-10-22')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-milestone-completed-2024-10-21')),
      findsNothing,
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('plan-milestone-ring'))),
      const Size.square(80),
    );
    await _pumpPlanPage(
      tester,
      dashboard: _singlePlanDashboard(now),
      now: now,
      onBackToPlans: () => backCount += 1,
      onStartSession: (_) => startCount += 1,
      onManualEdit: () => editCount += 1,
      viewportSize: const Size(390, 1100),
    );
    await tester.tap(find.byKey(const ValueKey('plan-open-details')));
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey('route-page-/plan')),
      matchesGoldenFile('../../goldens/plan/single_category_full_mobile.png'),
    );
    _expectRect(
      tester,
      const ValueKey('plan-single-header'),
      const Rect.fromLTWH(18, 18, 354, 44),
    );
    _expectRect(
      tester,
      const ValueKey('plan-milestone-card'),
      const Rect.fromLTWH(18, 80, 354, 112),
    );
    _expectRect(
      tester,
      const ValueKey('plan-milestone-week'),
      const Rect.fromLTWH(18, 208, 354, 70),
    );
    _expectRect(
      tester,
      const ValueKey('plan-single-session-one'),
      const Rect.fromLTWH(18, 325, 354, 59),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-single-session-two'),
      const Rect.fromLTWH(18, 394, 354, 61),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-single-session-five'),
      const Rect.fromLTWH(18, 601, 354, 59),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-volume-progress'),
      const Rect.fromLTWH(18, 709, 354, 108),
      tolerance: 1,
    );
    _expectRect(
      tester,
      const ValueKey('plan-settings'),
      const Rect.fromLTWH(18, 833, 354, 221),
      tolerance: 1,
    );
    await tester.tap(find.byKey(const ValueKey('plan-single-edit')));
    expect(find.byKey(const ValueKey('plan-single-all-plans')), findsNothing);
    await tester.tap(find.text('Start'));
    expect(editCount, 1);
    expect(startCount, 1);

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
    await tester.tap(find.byKey(const ValueKey('plan-single-back')));
    await tester.pump();
    expect(backCount, 1);
    expect(find.text('My Plans'), findsOneWidget);
    expect(find.text('日程'), findsNothing);
    expect(find.text('今天还没有计划任务'), findsNothing);
  });

  for (final viewport in const [Size(360, 800), Size(430, 932)]) {
    testWidgets(
      'all supplied plan states fit ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        for (final planCase in [
          (name: 'empty', dashboard: PlanDashboard.empty(weekOf: now)),
          (name: 'multi', dashboard: _multiCategoryDashboard(now)),
          (name: 'single', dashboard: _singlePlanDashboard(now)),
          (name: 'upcoming', dashboard: _upcomingPlanDashboard(now)),
        ]) {
          await _pumpPlanPage(
            tester,
            dashboard: planCase.dashboard,
            now: now,
            viewportSize: viewport,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${planCase.name} overview at ${viewport.width}',
          );
          if (!planCase.dashboard.isEmpty) {
            await tester.tap(find.byKey(const ValueKey('plan-open-details')));
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${planCase.name} details at ${viewport.width}',
            );
          }
        }
      },
    );
  }

  goldenTest('renders deterministic 2x design comparison fixtures', (
    tester,
  ) async {
    for (final designCase in [
      (
        dashboard: PlanDashboard.empty(weekOf: emptyNow),
        now: emptyNow,
        viewport: const Size(390, 1140),
        golden: '../../goldens/plan/empty_design_2x.png',
        openDetails: false,
      ),
      (
        dashboard: _multiCategoryDashboard(now),
        now: now,
        viewport: const Size(390, 683),
        golden: '../../goldens/plan/multi_category_design_2x.png',
        openDetails: false,
      ),
      (
        dashboard: _singlePlanDashboard(now),
        now: now,
        viewport: const Size(390, 1060),
        golden: '../../goldens/plan/single_category_design_2x.png',
        openDetails: true,
      ),
    ]) {
      await _pumpPlanPage(
        tester,
        dashboard: designCase.dashboard,
        now: designCase.now,
        viewportSize: designCase.viewport,
        devicePixelRatio: 2,
      );
      if (designCase.openDetails) {
        await tester.tap(find.byKey(const ValueKey('plan-open-details')));
        await tester.pump();
      }
      await expectLater(
        find.byKey(const ValueKey('route-page-/plan')),
        matchesGoldenFile(designCase.golden),
      );
    }
  });

  testWidgets(
    'lactation plan v1 shows schedule targets without fake volume progress',
    (tester) async {
      final start = DateTime(2026, 8, 11);
      final dashboard = PlanDashboard(
        weekOf: start,
        plans: [
          CarePlan(
            id: 'lactation-v1',
            category: PlanCategory.lactation,
            title: '15-Day Supply Plan',
            summary: 'Gradual schedule',
            startDate: start,
            endDate: DateTime(2026, 8, 25),
            durationDays: 15,
            goal: 'increase_supply',
            basisMode: 'history_analysis',
            pumpingSessionsPerDay: 6,
            breastfeedingAnchorsPerDay: 1,
            sessionsPerDay: 7,
          ),
        ],
      );

      await _pumpPlanPage(tester, dashboard: dashboard, now: start);
      await tester.tap(find.byKey(const ValueKey('plan-open-details')));
      await tester.pump();

      expect(find.text('Day 1/15'), findsOneWidget);
      expect(find.text('Increase Supply'), findsOneWidget);
      expect(find.text('Volume Progress'), findsNothing);
      expect(find.textContaining('600'), findsNothing);
      expect(find.textContaining('4200'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('7 sessions'), findsOneWidget);
    },
  );
}

TextStyle _renderedTextStyle(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.text.style!;
}

void _expectRect(
  WidgetTester tester,
  Key key,
  Rect expected, {
  double tolerance = 0.6,
}) {
  final actual = tester.getRect(find.byKey(key));
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$key left');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$key top');
  expect(
    actual.width,
    closeTo(expected.width, tolerance),
    reason: '$key width',
  );
  expect(
    actual.height,
    closeTo(expected.height, tolerance),
    reason: '$key height',
  );
}

Future<void> _pumpPlanPage(
  WidgetTester tester, {
  required PlanDashboard dashboard,
  required DateTime now,
  PlanRepository? repository,
  VoidCallback? onCreatePlan,
  VoidCallback? onOpenCalendar,
  VoidCallback? onOpenAllPlans,
  VoidCallback? onBackToPlans,
  VoidCallback? onChat,
  VoidCallback? onStartPump,
  ValueChanged<PlanSession>? onStartSession,
  VoidCallback? onManualEdit,
  Size viewportSize = const Size(390, 844),
  double devicePixelRatio = 1,
}) async {
  tester.view.physicalSize = Size(
    viewportSize.width * devicePixelRatio,
    viewportSize.height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Quicksand'),
      home: PlanPage(
        repository: repository ?? _FakePlanRepository(dashboard),
        now: () => now,
        onCreatePlan: onCreatePlan,
        onOpenCalendar: onOpenCalendar,
        onOpenAllPlans: onOpenAllPlans,
        onBackToPlans: onBackToPlans,
        onChat: onChat ?? () {},
        onStartPump: onStartPump ?? () {},
        onStartSession: onStartSession ?? (_) {},
        onManualEdit: onManualEdit,
      ),
    ),
  );
  final context = tester.element(
    find.byKey(const ValueKey('route-page-/plan')),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage(MomCozyAssets.planCozymateAvatar),
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
      weeklyCompletedSessions: 3,
      weeklyTotalSessions: 5,
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
    sessions: [
      PlanSession(
        id: 'one',
        planId: 'lactation',
        title: 'Pumping: Express 20min',
        scheduledAt: DateTime(now.year, now.month, now.day, 8),
        status: PlanSessionStatus.completed,
      ),
      PlanSession(
        id: 'two',
        planId: 'lactation',
        title: 'Pumping: Express 20min',
        scheduledAt: DateTime(now.year, now.month, now.day, 11),
        status: PlanSessionStatus.next,
        kind: PlanSessionKind.pumping,
      ),
      PlanSession(
        id: 'three',
        planId: 'lactation',
        title: 'Pumping: Evening power session 15min',
        scheduledAt: DateTime(now.year, now.month, now.day, 16),
        status: PlanSessionStatus.upcoming,
      ),
    ],
  );
}

PlanDashboard _mixedPlanDashboard(DateTime now) {
  final dashboard = _multiCategoryDashboard(now);
  return PlanDashboard(
    weekOf: now,
    plans: dashboard.plans,
    sessions: [
      ...dashboard.sessions.take(2),
      PlanSession(
        id: 'three',
        planId: 'pelvic',
        title: 'Pelvic Floor: Evening Stretches 15min',
        scheduledAt: DateTime(now.year, now.month, now.day, 16),
        status: PlanSessionStatus.next,
        kind: PlanSessionKind.pelvicFloor,
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
        scheduledAt: DateTime(now.year, now.month, now.day, 8),
        status: PlanSessionStatus.completed,
      ),
      PlanSession(
        id: 'two',
        planId: plan.id,
        title: 'Session 2',
        scheduledAt: DateTime(now.year, now.month, now.day, 11),
        status: PlanSessionStatus.next,
      ),
      PlanSession(
        id: 'three',
        planId: plan.id,
        title: 'Session 3',
        scheduledAt: DateTime(now.year, now.month, now.day, 14),
        status: PlanSessionStatus.upcoming,
      ),
      PlanSession(
        id: 'four',
        planId: plan.id,
        title: 'Session 4',
        scheduledAt: DateTime(now.year, now.month, now.day, 17),
        status: PlanSessionStatus.upcoming,
      ),
      PlanSession(
        id: 'five',
        planId: plan.id,
        title: 'Session 5',
        scheduledAt: DateTime(now.year, now.month, now.day, 20),
        status: PlanSessionStatus.upcoming,
      ),
    ],
  );
}

PlanDashboard _upcomingPlanDashboard(DateTime today) {
  final start = DateTime(today.year, today.month, today.day + 1);
  return PlanDashboard(
    weekOf: today,
    plans: [
      CarePlan(
        id: 'lactation-v1',
        category: PlanCategory.lactation,
        title: '15-Day Supply Plan',
        summary: 'Gradual schedule',
        startDate: start,
        endDate: start.add(const Duration(days: 14)),
        durationDays: 15,
        goal: 'increase_supply',
        pumpingSessionsPerDay: 6,
        breastfeedingAnchorsPerDay: 1,
        sessionsPerDay: 7,
      ),
    ],
    sessions: [
      PlanSession(
        id: 'future-session',
        planId: 'lactation-v1',
        title: 'Morning pumping session',
        scheduledAt: DateTime(start.year, start.month, start.day, 8),
        status: PlanSessionStatus.next,
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

class _EditablePlanRepository
    implements PlanRepository, PlanSessionMutationRepository {
  _EditablePlanRepository(this.dashboard);

  PlanDashboard dashboard;
  String? updatedSessionId;
  String? updatedTitle;
  DateTime? updatedAt;
  String? updatedStateSessionId;
  PlanTaskState? updatedState;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) async {
    return dashboard;
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    updatedSessionId = sessionId;
    updatedTitle = title;
    updatedAt = scheduledAt;
    dashboard = PlanDashboard(
      weekOf: dashboard.weekOf,
      plans: dashboard.plans,
      sessions: [
        for (final session in dashboard.sessions)
          if (session.id == sessionId)
            PlanSession(
              id: session.id,
              planId: session.planId,
              title: title,
              scheduledAt: scheduledAt,
              status: session.status,
              kind: session.kind,
              valueLabel: session.valueLabel,
            )
          else
            session,
      ],
    );
  }

  @override
  Future<void> updateSessionState({
    required String sessionId,
    required PlanTaskState state,
  }) async {
    updatedStateSessionId = sessionId;
    updatedState = state;
    dashboard = PlanDashboard(
      weekOf: dashboard.weekOf,
      plans: dashboard.plans,
      sessions: [
        for (final session in dashboard.sessions)
          if (session.id == sessionId)
            PlanSession(
              id: session.id,
              planId: session.planId,
              title: session.title,
              scheduledAt: session.scheduledAt,
              status: switch (state) {
                PlanTaskState.completed => PlanSessionStatus.completed,
                PlanTaskState.skipped => PlanSessionStatus.skipped,
                PlanTaskState.pending => PlanSessionStatus.next,
              },
              kind: session.kind,
              valueLabel: session.valueLabel,
            )
          else
            session,
      ],
    );
  }
}

class _RecordingPlanRepository implements PlanRepository {
  _RecordingPlanRepository(this.dashboard);

  final PlanDashboard dashboard;
  final List<DateTime> requestedDays = [];

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) async {
    requestedDays.add(weekOf);
    return PlanDashboard(
      weekOf: weekOf,
      plans: dashboard.plans,
      sessions: dashboard.sessions,
    );
  }
}

class _DeferredPlanRepository implements PlanRepository {
  final Completer<PlanDashboard> _completer = Completer<PlanDashboard>();
  int fetchCount = 0;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) {
    fetchCount += 1;
    return _completer.future;
  }

  void complete(PlanDashboard dashboard) => _completer.complete(dashboard);

  void completeIfPending() {
    if (!_completer.isCompleted) {
      _completer.complete(PlanDashboard.empty(weekOf: DateTime(2025, 10, 14)));
    }
  }
}

class _CachedDeferredPlanRepository extends _DeferredPlanRepository
    implements PlanDashboardSnapshotProvider {
  _CachedDeferredPlanRepository(this.cached);

  final PlanDashboard cached;

  @override
  PlanDashboard? snapshotFor({required DateTime weekOf}) => cached;
}
