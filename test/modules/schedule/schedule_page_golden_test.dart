import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/modules/schedule/domain/schedule.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  test(
    'agenda merges all-day tasks, personal events and consultations chronologically',
    () {
      PersonalScheduleEntry entry(String id, String time) =>
          PersonalScheduleEntry(
            id: id,
            title: id,
            date: LocalDate(2026, 9, 9),
            startTime: time,
            note: '',
            updatedAt: DateTime.utc(2026, 9, 9),
          );
      final page = SchedulePageData(
        personal: [
          entry('late', '20:00'),
          entry('early', '08:00'),
          entry('tie1', '11:00'),
          entry('tie2', '11:00'),
        ],
        appointments: [_appointment],
        plans: [_plan],
        episodes: [],
        serverTime: DateTime.utc(2026, 9, 9),
        hasMore: false,
      );
      expect(page.agendaOn(LocalDate(2026, 9, 9)).map((e) => e.title), [
        'Log how feeding went',
        'early',
        'tie1',
        'tie2',
        'Lactation consultation',
        'late',
      ]);
      expect(page.datesWithEvents().toSet(), {
        LocalDate(2026, 9, 9),
        LocalDate(2026, 9, 10),
      });
    },
  );
  testWidgets(
    'full viewport month and week match Figma geometry; local controls do not fetch',
    (tester) async {
      final repo = _ScheduleRepository(
        plans: [_plan],
        appointments: [_appointment],
      );
      await _mount(tester, repo);
      expect(
        find.text('Consultations, tasks, and everyday plans'),
        findsNothing,
      );
      expect(find.textContaining("Today's schedule"), findsNothing);
      final month = tester.getRect(
        find.byKey(const ValueKey('schedule-month-calendar')),
      );
      expect(month.left, 16);
      expect(month.top, 64);
      expect(month.width, 361);
      // English helper text may add a line; the calendar must grow instead of clipping.
      expect(month.height, greaterThanOrEqualTo(369));
      expect(
        tester.getRect(find.byKey(const ValueKey('schedule-add'))),
        const Rect.fromLTWH(329, 666, 48, 48),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('bottom-nav-chrome'))).top,
        762,
      );
      await _capture(tester, 'month');
      await tester.tap(find.text('Collapse calendar'));
      await tester.pumpAndSettle();
      expect(find.text('9/7–13'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('schedule-week-calendar')))
            .height,
        greaterThanOrEqualTo(149),
      );
      expect(repo.readCount, 1);
      final titles = [
        'Log how feeding went',
        'Baby checkup',
        'Lactation consultation',
      ];
      final ys = titles.map((s) => tester.getTopLeft(find.text(s)).dy).toList();
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      expect(find.text('Jamie Lee, IBCLC'), findsNothing);
      expect(find.text('Bring the growth records'), findsNothing);
      expect(find.text('Completed'), findsNothing);
      await _capture(tester, 'week');
      await tester.tap(find.text('Expand calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-09-23')));
      await tester.tap(find.text('Collapse calendar'));
      await tester.pumpAndSettle();
      expect(find.text('9/21–27'), findsOneWidget);
      expect(find.text('9/23'), findsOneWidget);
      expect(find.text('Nothing scheduled for this day'), findsOneWidget);
      expect(repo.readCount, 1);
      expect(
        find.byKey(const ValueKey('schedule-dot-2026-09-23')),
        findsNothing,
      );
      await _capture(tester, 'empty');
      await tester.tap(find.text('Expand calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-09-12')));
      await tester.pumpAndSettle();
      await _capture(tester, 'empty-month');
      await tester.tap(find.byTooltip('Add to schedule'));
      await tester.pumpAndSettle();
      await _capture(tester, 'create');
      await tester.tap(find.byTooltip('Close schedule item'));
      await tester.pumpAndSettle();
      expect(repo.readCount, 1);
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-09-09')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collapse calendar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byTooltip('More options for Baby checkup'),
      );
      await tester.tap(find.byTooltip('More options for Baby checkup'));
      await tester.pumpAndSettle();
      await _capture(tester, 'personal-menu');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await _capture(tester, 'edit');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.readCount, 1);
      await tester.tap(find.byTooltip('More options for Baby checkup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await _capture(tester, 'delete');
      await tester.tap(find.text('Keep item'));
      await tester.pumpAndSettle();
      expect(repo.readCount, 1);
    },
  );
  testWidgets(
    'uncached month never claims an empty day before its read finishes',
    (tester) async {
      final repo = _ScheduleRepository();
      await _mount(tester, repo);
      repo.pendingRead = Completer<void>();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.text('Loading schedule'), findsOneWidget);
      expect(find.text('Nothing scheduled for this day'), findsNothing);
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      repo.pendingRead!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load this month\'s schedule. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Nothing scheduled for this day'), findsNothing);
    },
  );
  testWidgets('first load retains shell until data is ready', (tester) async {
    final repo = _ScheduleRepository()..pendingRead = Completer<void>();
    await _mount(tester, repo, settle: false);
    expect(find.text('Loading schedule'), findsOneWidget);
    expect(find.text('Schedule'), findsNWidgets(2));
    await _capture(tester, 'loading');
    repo.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Loading schedule'), findsNothing);
  });
  testWidgets('offline retry is a real read and keeps navigation', (
    tester,
  ) async {
    final repo = _ScheduleRepository()
      ..readFailure = const ProductFailure(ProductFailureKind.offline);
    await _mount(tester, repo);
    await _capture(tester, 'offline');
    expect(find.text('Schedule'), findsNWidgets(2));
    expect(find.byTooltip('Add to schedule'), findsNothing);
    repo.readFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.readCount, 2);
    expect(find.text('Baby checkup'), findsOneWidget);
  });
  testWidgets(
    'refresh preserves agenda; failed refresh retries without blanking content',
    (tester) async {
      final repo = _ScheduleRepository();
      await _mount(tester, repo);
      repo.pendingRead = Completer<void>();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.text('Baby checkup'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-month-calendar')),
        findsOneWidget,
      );
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      repo.pendingRead!.complete();
      await refresh;
      await tester.pumpAndSettle();
      expect(
        find.text('Your last loaded schedule is still available'),
        findsOneWidget,
      );
      expect(find.text('Baby checkup'), findsOneWidget);
      await _capture(tester, 'refresh-failure');
      repo.readFailure = null;
      repo.pendingRead = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your last loaded schedule is still available'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'failed task update retains version and agenda until reconciliation',
    (tester) async {
      final repo = _ScheduleRepository(plans: [_plan])
        ..taskFailure = const ProductFailure(ProductFailureKind.unavailable);
      await _mount(tester, repo);
      await tester.tap(find.text('Collapse calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options for Log how feeding went'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark in progress'));
      await tester.pumpAndSettle();
      expect(find.text('Could not update task'), findsOneWidget);
      expect(find.text('Log how feeding went'), findsOneWidget);
      expect(repo.taskUpdates, isEmpty);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Could not update task'), findsNothing);
      expect(repo.readCount, 2);
    },
  );
  for (final width in [320.0, 393.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('existing care and appointment actions at $width/$scale', (
        tester,
      ) async {
        final repo = _ScheduleRepository(
          plans: [_plan],
          appointments: [_appointment],
        );
        String? plan;
        CareAppointment? appointment;
        await _mount(
          tester,
          repo,
          width: width,
          scale: scale,
          onPlan: (id) => plan = id,
          onAppointment: (a) => appointment = a,
        );
        await tester.tap(find.text('Collapse calendar'));
        await tester.pumpAndSettle();
        final taskMenu = find.byTooltip(
          'More options for Log how feeding went',
        );
        await tester.ensureVisible(taskMenu);
        await tester.tap(taskMenu);
        await tester.pumpAndSettle();
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        await tester.tap(find.text('Mark in progress'));
        await tester.pumpAndSettle();
        expect(repo.taskUpdates.single, ('one', 2, CareTaskStatus.inProgress));
        expect(repo.readCount, 1);
        await tester.tap(taskMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View care plan'));
        await tester.pumpAndSettle();
        expect(plan, 'episode-1');
        final appointmentMenu = find.byTooltip(
          'More options for Lactation consultation',
        );
        await tester.ensureVisible(appointmentMenu);
        await tester.tap(appointmentMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View appointment'));
        await tester.pumpAndSettle();
        expect(appointment?.id, 'appointment-1');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'pending task update prevents competing writes and retains version',
    (tester) async {
      final repo = _ScheduleRepository(plans: [_plan])
        ..pendingTask = Completer<void>();
      await _mount(tester, repo);
      final menu = find.byTooltip('More options for Log how feeding went');
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark in progress'));
      await tester.pump();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Mark in progress'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      repo.pendingTask!.complete();
      await tester.pumpAndSettle();
      expect(repo.taskUpdates.single, ('one', 2, CareTaskStatus.inProgress));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();
      expect(repo.taskUpdates.last, ('one', 3, CareTaskStatus.completed));
    },
  );
  testWidgets(
    'short large display can reach last task above floating button and navigation',
    (tester) async {
      final repo = _ScheduleRepository()
        ..personal = List.generate(
          100,
          (i) => PersonalScheduleEntry(
            id: 'event-$i',
            title: 'Event $i',
            date: LocalDate(2026, 9, 9),
            startTime: '09:00',
            note: '',
            updatedAt: DateTime.utc(2026, 9, 9),
          ),
        );
      await _mount(tester, repo, width: 320, height: 568, scale: 2);
      await tester.scrollUntilVisible(
        find.byTooltip('More options for Event 99'),
        300,
        maxScrolls: 150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byTooltip('More options for Event 99')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('schedule-add'))).dy,
        ),
      );
      await tester.tap(find.byTooltip('More options for Event 99'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  _ScheduleRepository repo, {
  double width = 393,
  double height = 844,
  double scale = 1,
  bool settle = true,
  ValueChanged<String>? onPlan,
  ValueChanged<CareAppointment>? onAppointment,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('schedule-capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          extendBody: true,
          bottomNavigationBar: const MomCozyBottomNavigation(
            location: '/schedule',
          ),
          body: SchedulePage(
            repository: repo,
            timezoneProvider: () async => 'Asia/Shanghai',
            catalogLoader: () async => _catalog,
            now: () => DateTime(2026, 9, 9),
            onOpenPlan: onPlan ?? (_) {},
            onOpenAppointment: onAppointment ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final asset in [
      'ArtworkSoftMe.png',
      'ArtworkSoftBaby.png',
      'AvatarCozymateNav.png',
    ]) {
      await precacheImage(
        AssetImage('assets/images/navigation_figma/$asset'),
        tester.element(find.byType(SchedulePage)),
      );
    }
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  debugDisableShadows = false;
  void repaint(RenderObject node) {
    node.markNeedsPaint();
    node.visitChildren(repaint);
  }

  repaint(tester.renderObject(find.byKey(const ValueKey('schedule-capture'))));
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('schedule-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = Directory('build/schedule-figma')..createSync(recursive: true);
    File('${out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
  debugDisableShadows = true;
}

final _catalog = ServiceCatalog(
  packages: [
    const ServicePackage(
      id: 'feeding-confidence',
      name: 'Feeding Confidence',
      subtitle: '',
      description: '',
      durationDays: 7,
      sessions: 2,
      priceMinor: 1,
      currency: 'USD',
      highlights: [],
      expertServices: [],
      continuousServices: [],
    ),
  ],
  providers: const [],
  availableRegions: const ['US'],
  paymentMode: PaymentMode.sandbox,
);

class _ScheduleRepository implements ScheduleRepository {
  _ScheduleRepository({this.plans = const [], this.appointments = const []});
  ProductFailure? taskFailure, readFailure;
  int readCount = 0;
  Completer<void>? pendingRead, pendingTask;
  List<PersonalScheduleEntry>? personal;
  final taskUpdates = <(String, int, CareTaskStatus)>[];
  final List<ScheduledPlan> plans;
  final List<CareAppointment> appointments;
  final _entry = PersonalScheduleEntry(
    id: 'personal-1',
    title: 'Baby checkup',
    date: LocalDate(2026, 9, 9),
    startTime: '09:30',
    note: 'Bring the growth records',
    updatedAt: DateTime.utc(2026, 9, 9),
  );

  @override
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  }) async {
    readCount++;
    await pendingRead?.future;
    if (readFailure case final failure?) throw failure;
    return SchedulePageData(
      personal: personal ?? [_entry],
      appointments: appointments,
      plans: plans,
      episodes: const [],
      serverTime: DateTime.utc(2026, 9, 9),
      hasMore: false,
    );
  }

  @override
  Future<PersonalScheduleEntry> create({
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    required String idempotencyKey,
  }) async => _entry;

  @override
  Future<PersonalScheduleEntry> update(
    PersonalScheduleEntry entry, {
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
  }) async => _entry;

  @override
  Future<void> delete(PersonalScheduleEntry entry) async {}

  @override
  Future<PublishedCarePlan> updateTask({
    required String publicationId,
    required String sourceKey,
    required int expectedVersion,
    required CareTaskStatus status,
  }) async {
    await pendingTask?.future;
    if (taskFailure case final error?) {
      taskFailure = null;
      throw error;
    }
    taskUpdates.add((sourceKey, expectedVersion, status));
    final index = plans.indexWhere((p) => p.publication.id == publicationId);
    final old = plans[index], p = old.publication;
    final next = PublishedCarePlan(
      id: p.id,
      planId: p.planId,
      consultationId: p.consultationId,
      revision: p.revision,
      title: p.title,
      summary: p.summary,
      goals: p.goals,
      tasks: [
        for (final task in p.tasks)
          task.content.sourceKey == sourceKey
              ? PublishedCareTask(
                  content: task.content,
                  status: status,
                  progressVersion: expectedVersion + 1,
                )
              : task,
      ],
      publisherName: p.publisherName,
      publishedAt: p.publishedAt,
    );
    plans[index] = ScheduledPlan(
      episodeId: old.episodeId,
      appointmentId: old.appointmentId,
      publication: next,
    );
    return next;
  }
}

final _appointment = CareAppointment(
  id: 'appointment-1',
  episodeId: 'episode-1',
  providerId: 'provider-1',
  providerName: 'Jamie Lee, IBCLC',
  startsAt: DateTime(2026, 9, 9, 11),
  endsAt: DateTime(2026, 9, 9, 12),
  timezone: 'Asia/Shanghai',
  region: 'US',
  status: AppointmentStatus.confirmed,
  holdExpiresAt: DateTime(2026, 9, 9),
  version: 2,
  intakeVersion: 1,
);
final _plan = ScheduledPlan(
  episodeId: 'episode-1',
  appointmentId: 'appointment-1',
  publication: PublishedCarePlan(
    id: 'publication-1',
    planId: 'plan-1',
    consultationId: 'consultation-1',
    revision: 2,
    title: 'Build a comfortable feeding routine',
    summary:
        "Use recent records to find a comfortable feeding position, notice your baby's hunger cues, and review them at your next consultation.",
    goals: const ['Feed comfortably'],
    tasks: [
      PublishedCareTask(
        content: CarePlanTaskContent(
          sourceKey: 'one',
          title: 'Log how feeding went',
          description: 'Note how your baby fed and how you felt.',
          dueLabel: 'Today',
          scheduledDate: LocalDate(2026, 9, 9),
        ),
        status: CareTaskStatus.completed,
        progressVersion: 2,
      ),
      PublishedCareTask(
        content: CarePlanTaskContent(
          sourceKey: 'two',
          title: 'Review comfortable feeding positions',
          description: 'Discuss with your consultant at your next appointment.',
          dueLabel: 'Tomorrow',
          scheduledDate: LocalDate(2026, 9, 10),
        ),
        status: CareTaskStatus.pending,
        progressVersion: 1,
      ),
    ],
    publisherName: 'Jamie Lee',
    publishedAt: DateTime(2026, 9, 9),
  ),
);
