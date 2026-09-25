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
    await tap(tester, find.byTooltip('Add to schedule'));
    await tester.enterText(find.byKey(const ValueKey('schedule-title')), title);
    await tester.pump();
  }

  Future<void> menu(WidgetTester tester, String title) =>
      tap(tester, find.byTooltip('More options for $title'));

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
    await tap(tester, find.text('Collapse calendar'));
    expect(find.text('9/7–13'), findsOneWidget);
    await tap(tester, find.text('Expand calendar'));
    expect(transport.queries.length, reads);
    await add(tester, 'My schedule');
    await tap(tester, find.byKey(const ValueKey('schedule-save')));
    expect(transport.personal.single['title'], 'My schedule');
    expect(transport.queries.length, reads);
    await menu(tester, 'My schedule');
    await tap(tester, find.text('Edit'));
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Updated event title',
    );
    await tap(tester, find.text('Save changes'));
    expect(transport.personal.single['title'], 'Updated event title');
    await menu(tester, 'Updated event title');
    await tap(tester, find.text('Delete'));
    await tap(tester, find.text('Keep item'));
    expect(transport.personal, hasLength(1));
    await menu(tester, 'Updated event title');
    await tap(tester, find.text('Delete'));
    await tap(tester, find.text('Delete item'));
    expect(transport.personal, isEmpty);
    expect(transport.queries.length, reads);
  });
  testWidgets(
    'schedule discard and failed save preserve draft with one retry key',
    (tester) async {
      await mount(tester);
      final reads = transport.queries.length;
      await add(tester, 'Keep this draft');
      await tap(tester, find.byTooltip('Close schedule item'));
      await tap(tester, find.text('Keep editing'));
      transport.failWrite = true;
      await tap(tester, find.byKey(const ValueKey('schedule-save')));
      expect(find.text('Try saving again'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('schedule-title')))
            .enabled,
        isTrue,
      );
      transport.failWrite = false;
      await tap(tester, find.text('Try saving again'));
      expect(transport.personal, hasLength(1));
      expect(transport.createKeys.toSet(), hasLength(1));
      await menu(tester, 'Keep this draft');
      await tap(tester, find.text('Edit'));
      await tester.enterText(
        find.byKey(const ValueKey('schedule-note')),
        'Do not save this note',
      );
      await tap(tester, find.byTooltip('Close schedule item'));
      await tap(tester, find.text('Leave'));
      expect(transport.personal.single['note'], '');
      expect(transport.queries.length, reads);
    },
  );
  testWidgets('schedule initial error retries and delete error retains row', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.failingReads.add('/v1/schedule'));
    transport.failingReads.clear();
    await tap(tester, find.text('Try again'));
    await add(tester, 'Keep row after delete failure');
    await tap(tester, find.byKey(const ValueKey('schedule-save')));
    await menu(tester, 'Keep row after delete failure');
    await tap(tester, find.text('Delete'));
    transport.failWrite = true;
    await tap(tester, find.text('Delete item'));
    expect(find.text('Could not delete. Please try again.'), findsOneWidget);
    expect(transport.personal, hasLength(1));
    transport.failWrite = false;
    await tap(tester, find.text('Try again'));
    await tap(tester, find.text('Delete item'));
    expect(transport.personal, isEmpty);
  });
  testWidgets('schedule existing task status and care plan route', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.seedCare());
    await menu(tester, 'Record an observation');
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tap(tester, find.text('Mark in progress'));
    expect(
      (transport.publication!['tasks'] as List).first['status'],
      'in_progress',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('Skip for now'));
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('Mark as pending'));
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('Mark completed'));
    expect(
      (transport.publication!['tasks'] as List).first['status'],
      'completed',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('View care plan'));
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
      await menu(tester, 'Lactation consultation');
      await tap(
        tester,
        find.text(
          status == 'completed'
              ? 'View consultation summary'
              : status == 'held'
              ? 'Confirm appointment'
              : 'View appointment',
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
