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
        '记录一次喂养感受',
        'early',
        'tie1',
        'tie2',
        '哺乳咨询',
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
      expect(find.text('咨询、行动与生活安排'), findsNothing);
      expect(find.textContaining('当天安排'), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('schedule-month-calendar'))),
        const Rect.fromLTWH(16, 64, 361, 369),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('schedule-add'))),
        const Rect.fromLTWH(329, 666, 48, 48),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('bottom-nav-chrome'))).top,
        762,
      );
      await _capture(tester, 'month');
      await tester.tap(find.text('收起日历'));
      await tester.pumpAndSettle();
      expect(find.text('9月7日–13日'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('schedule-week-calendar')))
            .height,
        149,
      );
      expect(repo.readCount, 1);
      final titles = ['记录一次喂养感受', '宝宝体检', '哺乳咨询'];
      final ys = titles.map((s) => tester.getTopLeft(find.text(s)).dy).toList();
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      expect(find.text('Jamie Lee, IBCLC'), findsNothing);
      expect(find.text('带好成长记录'), findsNothing);
      expect(find.text('已完成'), findsNothing);
      await _capture(tester, 'week');
      await tester.tap(find.text('展开日历'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-09-23')));
      await tester.tap(find.text('收起日历'));
      await tester.pumpAndSettle();
      expect(find.text('9月21日–27日'), findsOneWidget);
      expect(find.text('9月23日'), findsOneWidget);
      expect(find.text('这一天没有安排'), findsOneWidget);
      expect(repo.readCount, 1);
      expect(
        find.byKey(const ValueKey('schedule-dot-2026-09-23')),
        findsNothing,
      );
      await _capture(tester, 'empty');
      await tester.tap(find.text('展开日历'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-09-12')));
      await tester.pumpAndSettle();
      await _capture(tester, 'empty-month');
      await tester.tap(find.byTooltip('添加日程'));
      await tester.pumpAndSettle();
      await _capture(tester, 'create');
      await tester.tap(find.byTooltip('关闭日程'));
      await tester.pumpAndSettle();
      expect(repo.readCount, 1);
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-09-09')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('收起日历'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('更多宝宝体检选项'));
      await tester.tap(find.byTooltip('更多宝宝体检选项'));
      await tester.pumpAndSettle();
      await _capture(tester, 'personal-menu');
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await _capture(tester, 'edit');
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(repo.readCount, 1);
      await tester.tap(find.byTooltip('更多宝宝体检选项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await _capture(tester, 'delete');
      await tester.tap(find.text('保留日程'));
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
      await tester.tap(find.byTooltip('下个月'));
      await tester.pump();
      expect(find.text('正在读取日程'), findsOneWidget);
      expect(find.text('这一天没有安排'), findsNothing);
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      repo.pendingRead!.complete();
      await tester.pumpAndSettle();
      expect(find.text('这个月的日程暂未读取，请重试。'), findsOneWidget);
      expect(find.text('这一天没有安排'), findsNothing);
    },
  );
  testWidgets('first load retains shell until data is ready', (tester) async {
    final repo = _ScheduleRepository()..pendingRead = Completer<void>();
    await _mount(tester, repo, settle: false);
    expect(find.text('正在读取日程'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    await _capture(tester, 'loading');
    repo.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(find.text('正在读取日程'), findsNothing);
  });
  testWidgets('offline retry is a real read and keeps navigation', (
    tester,
  ) async {
    final repo = _ScheduleRepository()
      ..readFailure = const ProductFailure(ProductFailureKind.offline);
    await _mount(tester, repo);
    await _capture(tester, 'offline');
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.byTooltip('添加日程'), findsNothing);
    repo.readFailure = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(repo.readCount, 2);
    expect(find.text('宝宝体检'), findsOneWidget);
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
      expect(find.text('宝宝体检'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-month-calendar')),
        findsOneWidget,
      );
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      repo.pendingRead!.complete();
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('已保留上次的日程'), findsOneWidget);
      expect(find.text('宝宝体检'), findsOneWidget);
      await _capture(tester, 'refresh-failure');
      repo.readFailure = null;
      repo.pendingRead = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('已保留上次的日程'), findsNothing);
    },
  );
  testWidgets(
    'failed task update retains version and agenda until reconciliation',
    (tester) async {
      final repo = _ScheduleRepository(plans: [_plan])
        ..taskFailure = const ProductFailure(ProductFailureKind.unavailable);
      await _mount(tester, repo);
      await tester.tap(find.text('收起日历'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多记录一次喂养感受选项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标记进行中'));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法更新任务'), findsOneWidget);
      expect(find.text('记录一次喂养感受'), findsOneWidget);
      expect(repo.taskUpdates, isEmpty);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法更新任务'), findsNothing);
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
        await tester.tap(find.text('收起日历'));
        await tester.pumpAndSettle();
        final taskMenu = find.byTooltip('更多记录一次喂养感受选项');
        await tester.ensureVisible(taskMenu);
        await tester.tap(taskMenu);
        await tester.pumpAndSettle();
        expect(find.text('编辑'), findsNothing);
        expect(find.text('删除'), findsNothing);
        await tester.tap(find.text('标记进行中'));
        await tester.pumpAndSettle();
        expect(repo.taskUpdates.single, ('one', 2, CareTaskStatus.inProgress));
        expect(repo.readCount, 1);
        await tester.tap(taskMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看照护方案'));
        await tester.pumpAndSettle();
        expect(plan, 'episode-1');
        final appointmentMenu = find.byTooltip('更多哺乳咨询选项');
        await tester.ensureVisible(appointmentMenu);
        await tester.tap(appointmentMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看预约'));
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
      final menu = find.byTooltip('更多记录一次喂养感受选项');
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('标记进行中'));
      await tester.pump();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('标记进行中'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      repo.pendingTask!.complete();
      await tester.pumpAndSettle();
      expect(repo.taskUpdates.single, ('one', 2, CareTaskStatus.inProgress));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('标记已完成'));
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
            title: '安排 $i',
            date: LocalDate(2026, 9, 9),
            startTime: '09:00',
            note: '',
            updatedAt: DateTime.utc(2026, 9, 9),
          ),
        );
      await _mount(tester, repo, width: 320, height: 568, scale: 2);
      await tester.scrollUntilVisible(
        find.byTooltip('更多安排 99选项'),
        300,
        maxScrolls: 150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byTooltip('更多安排 99选项')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('schedule-add'))).dy,
        ),
      );
      await tester.tap(find.byTooltip('更多安排 99选项'));
      await tester.pumpAndSettle();
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
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
      name: '喂养安心',
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
    title: '宝宝体检',
    date: LocalDate(2026, 9, 9),
    startTime: '09:30',
    note: '带好成长记录',
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
    title: '建立安心的喂养节奏',
    summary: '结合近期记录，保持舒适的喂养姿势，留意宝宝的饥饿信号，并在下次咨询时一起回顾。',
    goals: const ['舒适地喂养'],
    tasks: [
      PublishedCareTask(
        content: CarePlanTaskContent(
          sourceKey: 'one',
          title: '记录一次喂养感受',
          description: '记录宝宝的表现和自己的感受。',
          dueLabel: '今天',
          scheduledDate: LocalDate(2026, 9, 9),
        ),
        status: CareTaskStatus.completed,
        progressVersion: 2,
      ),
      PublishedCareTask(
        content: CarePlanTaskContent(
          sourceKey: 'two',
          title: '回顾舒适的姿势',
          description: '在下次咨询时和专家一起讨论。',
          dueLabel: '明天',
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
