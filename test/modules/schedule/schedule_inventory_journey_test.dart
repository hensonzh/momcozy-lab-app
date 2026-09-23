import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/schedule_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late ScheduleInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  Future<void> mount(
    WidgetTester tester, {
    void Function(ScheduleInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = ScheduleInventoryTransport();
    prepare?.call(transport);
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),

        session: session,
        supportsSessionAutoRefresh: false,
        now: () => inventoryMomNow,
        timezoneProvider: () async => 'Asia/Shanghai',
      ),
    );
    final store = MemoryMomCozySessionStore(session);
    final platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: runtime,
      sessionStore: store,
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        sessionStore: store,
        routeIntentPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Long capture visits lazy children. Decode both local images before
      // comparing any viewport so later dialogs see the same loaded page.
      for (final asset in [
        MomCozyAssets.agentAvatar,
        'assets/images/mom_home/cozymate_avatar.png',
        'assets/images/mom_home/expert_group.png',
        'assets/images/mom/milk-hero.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.text('Schedule'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/schedule');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.restorationId != 'editable' &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> add(WidgetTester tester, String title) async {
    await tap(tester, find.byTooltip('添加日程'));
    await tester.enterText(find.byKey(const ValueKey('schedule-title')), title);
    await tester.pump();
  }

  Future<void> menu(WidgetTester tester, String title) =>
      tap(tester, find.byTooltip('更多$title选项'));

  // The September 20 design replaces the old service filter, checkboxes and
  // result-unknown screens. Preserve the real router/HTTP boundary here; visual
  // evidence against Figma lives in schedule_page_golden_test.dart.
  testWidgets('schedule real shell, local calendar and personal CRUD', (
    tester,
  ) async {
    await mount(tester);
    expect(
      tester.getRect(find.byKey(const ValueKey('schedule-add'))),
      const Rect.fromLTWH(329, 666, 48, 48),
    );
    final reads = transport.queries.length;
    await tap(tester, find.text('收起日历'));
    expect(find.text('9月7日–13日'), findsOneWidget);
    await tap(tester, find.text('展开日历'));
    expect(transport.queries.length, reads);
    await add(tester, '我的日程');
    await tap(tester, find.byKey(const ValueKey('schedule-save')));
    expect(transport.personal.single['title'], '我的日程');
    expect(transport.queries.length, reads);
    await menu(tester, '我的日程');
    await tap(tester, find.text('编辑'));
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      '新的名称',
    );
    await tap(tester, find.text('保存修改'));
    expect(transport.personal.single['title'], '新的名称');
    await menu(tester, '新的名称');
    await tap(tester, find.text('删除'));
    await tap(tester, find.text('保留日程'));
    expect(transport.personal, hasLength(1));
    await menu(tester, '新的名称');
    await tap(tester, find.text('删除'));
    await tap(tester, find.text('确认删除'));
    expect(transport.personal, isEmpty);
    expect(transport.queries.length, reads);
  });
  testWidgets(
    'schedule discard and failed save preserve draft with one retry key',
    (tester) async {
      await mount(tester);
      final reads = transport.queries.length;
      await add(tester, '保留草稿');
      await tap(tester, find.byTooltip('关闭日程'));
      await tap(tester, find.text('继续填写'));
      transport.failWrite = true;
      await tap(tester, find.byKey(const ValueKey('schedule-save')));
      expect(find.text('重试保存'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('schedule-title')))
            .enabled,
        isTrue,
      );
      transport.failWrite = false;
      await tap(tester, find.text('重试保存'));
      expect(transport.personal, hasLength(1));
      expect(transport.createKeys.toSet(), hasLength(1));
      await menu(tester, '保留草稿');
      await tap(tester, find.text('编辑'));
      await tester.enterText(
        find.byKey(const ValueKey('schedule-note')),
        '不要保存',
      );
      await tap(tester, find.byTooltip('关闭日程'));
      await tap(tester, find.text('离开'));
      expect(transport.personal.single['note'], '');
      expect(transport.queries.length, reads);
    },
  );
  testWidgets('schedule initial error retries and delete error retains row', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.failingReads.add('/v1/schedule'));
    transport.failingReads.clear();
    await tap(tester, find.text('重试'));
    await add(tester, '删除失败保留');
    await tap(tester, find.text('添加到日程'));
    await menu(tester, '删除失败保留');
    await tap(tester, find.text('删除'));
    transport.failWrite = true;
    await tap(tester, find.text('确认删除'));
    expect(find.text('删除失败，请重试'), findsOneWidget);
    expect(transport.personal, hasLength(1));
    transport.failWrite = false;
    await tap(tester, find.text('重试'));
    await tap(tester, find.text('确认删除'));
    expect(transport.personal, isEmpty);
  });
  testWidgets('schedule existing task status and care plan route', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.seedCare());
    await menu(tester, 'Record an observation');
    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
    await tap(tester, find.text('标记进行中'));
    expect(
      (transport.publication!['tasks'] as List).first['status'],
      'in_progress',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('暂时跳过'));
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('恢复待完成'));
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('标记已完成'));
    expect(
      (transport.publication!['tasks'] as List).first['status'],
      'completed',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('查看照护方案'));
    expect(router.state.uri.path, '/services/episodes/service-episode');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/schedule');
  });
  for (final status in [
    'confirmed',
    'completed',
    'held',
    'cancelled',
    'expired',
  ]) {
    testWidgets('schedule appointment $status reuses production route', (
      tester,
    ) async {
      await mount(
        tester,
        prepare: (t) {
          t.seedCare();
          t.appointment!['status'] = status;
        },
      );
      await menu(tester, '哺乳咨询');
      await tap(
        tester,
        find.text(
          status == 'completed'
              ? '查看咨询总结'
              : status == 'held'
              ? '确认预约'
              : '查看预约',
        ),
      );
      expect(
        router.state.uri.path,
        '/services/appointments/service-appointment/${status == 'completed' ? 'summary' : 'room'}',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/schedule');
      expect(tester.takeException(), isNull);
    });
  }
}
