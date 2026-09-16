@Tags(['golden'])
library;

import 'dart:async';
import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/modules/schedule/domain/schedule.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'task menu writes progress with the current version at $width/$scale',
        (tester) async {
          await loadMomCozyTestFonts();
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _ScheduleRepository(plans: [_plan]);
          String? opened;
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: momCozyTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SchedulePage(
                  repository: repo,
                  timezoneProvider: () async => 'Asia/Shanghai',
                  catalogLoader: () async => _catalog,
                  now: () => DateTime(2026, 9, 9),
                  onOpenPlan: (id) => opened = id,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final menu = find.byTooltip('更多记录一次喂养感受选项');
          await tester.ensureVisible(menu);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/schedule-task-menu-${width.toInt()}.png',
              ),
            );
          }
          await tester.tap(find.text('标记进行中'));
          await tester.pumpAndSettle();
          expect(repo.taskUpdates.last, ('one', 2, CareTaskStatus.inProgress));
          expect(find.text('进行中'), findsWidgets);
          for (final action in [
            ('暂时跳过', CareTaskStatus.skipped),
            ('恢复待完成', CareTaskStatus.pending),
          ]) {
            await tester.ensureVisible(menu);
            await tester.pumpAndSettle();
            await tester.tap(menu);
            await tester.pumpAndSettle();
            await tester.tap(find.text(action.$1));
            await tester.pumpAndSettle();
            expect(repo.plans.first.publication.tasks.first.status, action.$2);
          }
          expect(repo.taskUpdates.map((e) => e.$2).toList(), [2, 3, 4]);
          await tester.ensureVisible(menu);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text('查看服务计划'));
          await tester.pumpAndSettle();
          expect(opened, 'episode-1');
          repo.taskFailure = const ProductFailure(
            ProductFailureKind.unavailable,
          );
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text('标记进行中'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('刷新日程'));
          await tester.pumpAndSettle();
          expect(find.text('暂时无法确认任务状态，请刷新日程后核对。'), findsOneWidget);
          await tester.tap(find.text('刷新日程'));
          await tester.pumpAndSettle();
          expect(find.text('暂时无法确认任务状态，请刷新日程后核对。'), findsNothing);
          expect(
            repo.plans.first.publication.tasks.first.status,
            CareTaskStatus.pending,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('service periods use actual dates and the display filter', (
    tester,
  ) async {
    await loadMomCozyTestFonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CareEpisode episode(String id, int start, int end) => CareEpisode(
      id: id,
      orderId: 'order-$id',
      packageId: 'feeding-confidence',
      status: CareEpisodeStatus.active,
      stage: CareStage.activeCare,
      totalSessions: 2,
      remainingSessions: 2,
      version: 1,
      startsAt: DateTime(2026, 9, start),
      endsAt: DateTime(2026, 9, end),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          body: SchedulePage(
            repository: _ScheduleRepository(
              episodes: [episode('one', 9, 15), episode('two', 20, 25)],
            ),
            timezoneProvider: () async => 'Asia/Shanghai',
            catalogLoader: () async => _catalog,
            now: () => DateTime(2026, 9, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('9月20日，服务期内'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('9月20日，服务期内'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
    expect(find.bySemanticsLabel('9月16日'), findsOneWidget);
    await tester.tap(find.byTooltip('切换日历显示的服务包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('喂养安心 · 余 2 次').first);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('9月20日，服务期内'), findsNothing);
    expect(find.bySemanticsLabel('9月9日，有安排，服务期内'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('published care plan and appointment at $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? openedPlan;
        CareAppointment? openedAppointment;
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SchedulePage(
                repository: _ScheduleRepository(
                  plans: [_plan],
                  appointments: [_appointment],
                ),
                timezoneProvider: () async => 'Asia/Shanghai',
                catalogLoader: () async => _catalog,
                now: () => DateTime(2026, 9, 9, 10),
                onOpenPlan: (id) => openedPlan = id,
                onOpenAppointment: (value) => openedAppointment = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('已确认'), findsOneWidget);
        if (width == 390 && scale == 1 || width == 320 && scale == 2) {
          await _extraShot(
            tester,
            'overview-${width.toInt()}-${scale.toInt()}x',
          );
        }
        await tester.ensureVisible(find.text('查看'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看'));
        expect(openedAppointment?.id, _appointment.id);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/schedule-care-${width.toInt()}.png',
            ),
          );
        }
        await tester.scrollUntilVisible(
          find.text('当前照护方案'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('当前照护方案'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('当前照护方案'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('查看照护方案 →'));
        await tester.pumpAndSettle();
        expect(find.text('1/2'), findsOneWidget);
        expect(find.text('v2 · 已发布'), findsOneWidget);
        expect(find.text(_plan.publication.summary), findsOneWidget);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/schedule-plan-${width.toInt()}.png',
            ),
          );
        }
        await tester.tap(find.text('查看照护方案 →'));
        expect(openedPlan, _plan.episodeId);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('schedule month and selected day agenda at $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SchedulePage(
              repository: _ScheduleRepository(),
              timezoneProvider: () async => 'Asia/Shanghai',
              catalogLoader: () async => _catalog,
              now: () => DateTime(2026, 9, 9, 10),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              width == 390
                  ? '../../goldens/product_baseline/schedule-390.png'
                  : '../../goldens/design_system/schedule-${width.toInt()}.png',
            ),
          );
        }
        await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('2026年10月'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'short large initial load error retries and cached refresh retains agenda',
    (tester) async {
      final repo = _ScheduleRepository()..pendingRead = Completer<void>();
      await _mountExtra(tester, repo, short: true, scale: 2, settle: false);
      expect(find.text('正在读取日程'), findsOneWidget);
      await _extraShot(tester, 'short-loading');
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      repo.pendingRead!.complete();
      await tester.pumpAndSettle();
      expect(find.text('网络未连接，请连接后重试'), findsOneWidget);
      await _extraShot(tester, 'short-offline');
      repo.readFailure = null;
      await tester.ensureVisible(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月'), findsOneWidget);
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('重试'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('宝宝体检'), findsOneWidget);
      await _extraShot(tester, 'short-refresh-error');
    },
  );
  testWidgets(
    'task write disables competing changes and keeps server version',
    (tester) async {
      final repo = _ScheduleRepository(plans: [_plan])
        ..pendingTask = Completer<void>();
      await _mountExtra(tester, repo);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      final menu = find.byTooltip('更多记录一次喂养感受选项');
      await tester.tap(menu);
      await tester.pumpAndSettle();
      for (final item in tester.widgetList<PopupMenuItem<String>>(
        find.byType(PopupMenuItem<String>),
      )) {
        if (item.value != 'plan') expect(item.enabled, isFalse);
      }
      await _extraShot(tester, 'task-busy');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      repo.pendingTask!.complete();
      await tester.pumpAndSettle();
      expect(repo.taskUpdates.single, ('one', 2, CareTaskStatus.pending));
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
        isNotNull,
      );
    },
  );
  testWidgets(
    'hundred loaded entries scroll to final action on short large display',
    (tester) async {
      final repo = _ScheduleRepository()
        ..personal = List.generate(
          100,
          (i) => PersonalScheduleEntry(
            id: 'event-$i',
            title: '安排 $i',
            date: LocalDate(2026, 9, 9),
            startTime: '09:00',
            note: '已加载的个人日程',
            updatedAt: DateTime.utc(2026, 9, 9),
          ),
        );
      await _mountExtra(tester, repo, short: true, scale: 2);
      await tester.scrollUntilVisible(
        find.byTooltip('更多安排 99选项'),
        300,
        maxScrolls: 150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('添加日程').hitTestable(), findsOneWidget);
      await _extraShot(tester, 'long-agenda-end');
      await tester.tap(find.byTooltip('更多安排 99选项'));
      await tester.pumpAndSettle();
      expect(find.text('修改'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    },
  );
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
  _ScheduleRepository({
    this.episodes = const [],
    this.plans = const [],
    this.appointments = const [],
  });
  ProductFailure? taskFailure, readFailure;
  Completer<void>? pendingRead, pendingTask;
  List<PersonalScheduleEntry>? personal;
  final taskUpdates = <(String, int, CareTaskStatus)>[];
  final List<CareEpisode> episodes;
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
    await pendingRead?.future;
    if (readFailure case final failure?) throw failure;
    return SchedulePageData(
      personal: personal ?? [_entry],
      appointments: appointments,
      plans: plans,
      episodes: episodes,
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

Future<void> _mountExtra(
  WidgetTester tester,
  _ScheduleRepository repo, {
  bool short = false,
  double scale = 1,
  bool settle = true,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(320, short ? 568 : 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SchedulePage(
          repository: repo,
          timezoneProvider: () async => 'Asia/Shanghai',
          catalogLoader: () async => _catalog,
          now: () => DateTime(2026, 9, 9),
          onOpenPlan: (_) {},
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _extraShot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/design_system/schedule-$name.png'),
  );
}
