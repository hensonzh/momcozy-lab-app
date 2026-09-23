import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mom_home_sections.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/consultation_inventory_transport.dart';
import '../../support/schedule_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/consultation_inventory_devices.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late ConsultationInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late ConsultationInventoryDevices devices;
  Future<void> mount(
    WidgetTester tester, {
    void Function(ConsultationInventoryTransport)? prepare,
    bool loading = false,
    ConsultationInventoryTransport? transportOverride,
  }) async {
    previous = null;
    devices = ConsultationInventoryDevices()..install();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = transportOverride ?? ConsultationInventoryTransport();
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
    await tester.tap(find.text('Me'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/me');
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

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/services/appointments/service-appointment/room',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/consultation-journey-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/consultation-journey-$state-393.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Me bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories/codecs and LiveKit device checks; isolated HTTP and native method channels, sandbox room, fixed clock/timezone; no real OS permission dialog or remote media',
      'test':
          'test/modules/consultation/consultation_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/consultation-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const bookingRoute = '/services/episodes/service-episode/booking';
  const roomRoute = '/services/appointments/service-appointment/room';
  const intakeRoute = '/services/appointments/service-appointment/intake';

  Future<void> bookingEntry(WidgetTester tester) async {
    await tap(tester, find.byType(MomExpertPlanEntry));
    await tap(tester, find.text('查看我的服务'));
    await tap(tester, find.text('开始预约'));
    expect(router.state.uri.path, bookingRoute);
  }

  Future<void> roomEntry(WidgetTester tester) async {
    await bookingEntry(tester);
    await tap(tester, find.widgetWithText(OutlinedButton, '咨询前准备'));
    expect(router.state.uri.path, roomRoute);
  }

  Future<void> pollRoom(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<void> deviceReady(WidgetTester tester) async {
    // Native EventChannel cleanup progresses outside the widget fake clock.
    // Bound the wait and assert readiness instead of treating a quiet frame as completion.
    for (var i = 0; i < 30 && find.text('摄像头和麦克风均可用').evaluate().isEmpty; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(
      find.text('摄像头和麦克风均可用'),
      findsOneWidget,
      reason: devices.calls.join(', '),
    );
  }

  Future<void> enterReadyRoom(WidgetTester tester) async {
    await tap(tester, find.text('开始咨询'));
    await deviceReady(tester);
    await tap(tester, find.text('继续确认'));
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, greaterThan(0));
  }

  testWidgets('inventory consultation preparation gates and intake route', (
    tester,
  ) async {
    await mount(tester);
    transport.roomData['intake_ready'] = false;
    transport.intake = null;
    transport.appointment!['intake_version'] = 0;
    transport.consents.clear();
    await roomEntry(tester);
    await capture(
      tester,
      'preparation-intake-required',
      'Booking consultation preparation → missing intake blocks start',
    );
    await tap(tester, find.text('查看信息采集表'));
    await capture(
      tester,
      'preparation-to-intake',
      'Preparation missing-information CTA → actual intake route',
      route: intakeRoute,
    );
    await tap(tester, find.text('返回'));
    transport.roomData['intake_ready'] = true;
    transport.roomData['case_consent'] = false;
    await pollRoom(tester);
    await capture(
      tester,
      'preparation-case-consent-required',
      'Refresh room with withdrawn case consent → sharing notice',
    );
    transport.roomData['case_consent'] = true;
    transport.roomData['opens_at'] = inventoryMomNow
        .add(const Duration(hours: 2))
        .toIso8601String();
    await pollRoom(tester);
    await capture(
      tester,
      'preparation-too-early',
      'Server entry window not open → start disabled and opening time shown',
    );
    transport.roomData['demo_early_join'] = true;
    await pollRoom(tester);
    await capture(
      tester,
      'preparation-demo-early',
      'Server allows sandbox early join → test-mode preparation',
    );
    transport.roomData['video_provider'] = 'disabled';
    await pollRoom(tester);
    await capture(
      tester,
      'preparation-video-disabled',
      'Video service disabled → unavailable explanation',
    );
    transport.roomData['video_provider'] = 'sandbox';
    transport.roomData['demo_early_join'] = false;
    transport.roomData['opens_at'] = inventoryMomNow
        .subtract(const Duration(hours: 2))
        .toIso8601String();
    transport.roomData['closes_at'] = inventoryMomNow
        .subtract(const Duration(minutes: 1))
        .toIso8601String();
    await pollRoom(tester);
    await capture(
      tester,
      'preparation-window-expired',
      'Entry window elapsed → rebook action',
    );
    await tap(tester, find.text('重新预约'));
    await capture(
      tester,
      'preparation-rebook',
      'Expired preparation rebook → actual booking route',
      route: bookingRoute,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'inventory consultation device failure retry consent and room entry',
    (tester) async {
      await mount(tester);
      await roomEntry(tester);
      await capture(
        tester,
        'preparation-ready',
        'Booked active service → consultation preparation',
      );
      devices.denied = true;
      devices.gate = Completer<void>();
      await tap(tester, find.text('开始咨询'));
      await capture(
        tester,
        'device-checking',
        'Device probe pending → permission check in progress',
      );
      devices.gate!.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'device-denied',
        'Start consultation → device API denial shown in check dialog',
      );
      expect(find.text('检查未通过，请重试'), findsOneWidget);
      devices.denied = false;
      await tap(tester, find.text('开始检测'));
      await deviceReady(tester);
      await capture(
        tester,
        'device-recovered',
        'Retry device APIs after permission recovery → ready',
      );
      expect(
        find.text('摄像头和麦克风均可用'),
        findsOneWidget,
        reason: devices.calls.join(', '),
      );
      await tap(tester, find.text('继续确认'));
      await capture(
        tester,
        'start-confirmation',
        'Device check success → location and missing video consent',
      );
      await tap(tester, find.text('去授权'));
      await capture(
        tester,
        'video-consent',
        'Video authorization CTA → explicit episode consent dialog',
      );
      await tap(tester, find.byKey(const ValueKey('room-video-consent')));
      await capture(
        tester,
        'video-consent-selected',
        'Consent checked → confirmation enabled, no grant before submit',
      );
      await tap(tester, find.text('确认视频授权'));
      await capture(
        tester,
        'video-consent-granted',
        'Submit video consent → actual start confirmation restored',
      );
      await tap(tester, find.text('确认并进入咨询室'));
      await capture(
        tester,
        'waiting-room',
        'Confirm location and enter → sandbox waiting room',
      );
      expect(transport.connectionNumber, 1);
      await tap(tester, find.text('离开房间'));
      await capture(
        tester,
        'leave-confirmation',
        'Leave waiting room → confirmation overlay',
      );
      await tap(tester, find.text('留在房间'));
      await capture(
        tester,
        'leave-retained',
        'Stay in room → same waiting connection retained',
      );
      expect(transport.connectionNumber, 1);
      transport.consultation(status: 'in_progress');
      transport.roomData['participants'] = [
        {
          'role': 'ibclc',
          'presence': 'joined',
          'connection_version': 1,
          'joined_at': inventoryMomNow.toIso8601String(),
          'last_seen_at': inventoryMomNow.toIso8601String(),
        },
      ];
      await pollRoom(tester);
      await capture(
        tester,
        'consultation-active',
        'Server reports expert joined and consultation started → active room',
      );
      await tap(tester, find.text('离开房间'));
      await tap(tester, find.text('暂时离开'));
      await capture(
        tester,
        'left-to-booking',
        'Confirm temporary leave → actual booking route; consultation not ended',
        route: bookingRoute,
      );
      expect(
        transport.requests.any(
          (r) => (r['path'] as String).endsWith('/room/end'),
        ),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inventory consultation current summary publication task updates and routes',
    (tester) async {
      await mount(
        tester,
        transportOverride: ScheduleInventoryTransport()..showCare = true,
      );
      transport.roomData['video_consent'] = true;
      await roomEntry(tester);
      await enterReadyRoom(tester);
      transport.consultation(status: 'in_progress');
      await pollRoom(tester);
      transport.consultation(
        status: 'note_pending',
        roomStatus: 'closing',
        endReason: 'completed',
      );
      await pollRoom(tester);
      await tap(tester, find.text('查看咨询总结'));
      const summaryRoute = '/services/appointments/service-appointment/summary';
      // Pending summary and preceding room states are already captured by G01/G02.
      previous =
          'test/goldens/ui_inventory/consultation-journey-current-outcome-summary-393.png';
      transport.publishSummary();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'current-summary-published',
        'Periodic pending-summary refresh receives published plan',
        route: summaryRoute,
      );
      await tap(tester, find.text('查看怎么做'));
      expect(find.byTooltip('关闭行动详情'), findsOneWidget);
      await capture(
        tester,
        'current-summary-task-detail',
        'Published task → action detail and progress choices',
        route: summaryRoute,
      );
      await tap(tester, find.text('进行中'));
      await capture(
        tester,
        'current-summary-task-in-progress',
        'Set task progress → persisted in-progress state',
        route: summaryRoute,
      );
      transport.failingWrites.add(
        '/v1/care/plan-publications/inventory-publication/tasks/log-observation',
      );
      await tap(tester, find.text('已完成'));
      await capture(
        tester,
        'current-summary-task-uncertain',
        'Task update unavailable → previous progress retained, retry required',
        route: summaryRoute,
      );
      transport.failingWrites.clear();
      await tap(tester, find.text('重试').last);
      await capture(
        tester,
        'current-summary-task-recovered',
        'Retry original progress update → completed state',
        route: summaryRoute,
      );
      await tap(tester, find.text('暂时跳过'));
      await capture(
        tester,
        'current-summary-task-skipped',
        'Change completed task to skipped → explicit progress state',
        route: summaryRoute,
      );
      await tap(tester, find.byTooltip('关闭行动详情'));
      await capture(
        tester,
        'current-summary-task-return',
        'Close task detail → updated summary',
        route: summaryRoute,
      );
      await tap(tester, find.text('查看完整行动计划 →'));
      expect(find.text('暂时无法载入，请稍后重试'), findsNothing);
      expect(find.text('日程'), findsWidgets);
      await capture(
        tester,
        'current-summary-full-plan',
        'Summary → full action plan opens Schedule',
        route: '/schedule',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, summaryRoute);
      await tap(tester, find.text('咨询与服务信息'));
      await capture(
        tester,
        'current-summary-service-information',
        'Expand consultation and service information → progress entry',
        route: summaryRoute,
      );
      await tap(tester, find.text('查看服务进度'));
      await capture(
        tester,
        'current-summary-to-progress',
        'Summary service progress → episode timeline',
        route: '/services/episodes/service-episode',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('inventory consultation preflight rejection and retry boundaries', (
    tester,
  ) async {
    await mount(tester);
    await roomEntry(tester);
    await tap(tester, find.text('开始咨询'));
    await deviceReady(tester);
    await tap(tester, find.text('继续确认'));
    await tap(tester, find.text('去授权'));
    await tap(tester, find.byKey(const ValueKey('room-video-consent')));
    final consentPollGate = Completer<void>();
    transport.readGates['/v1/care/appointments/service-appointment/room'] =
        consentPollGate;
    transport.failingWrites.add('/v1/care/episodes/service-episode/consents');
    await tap(tester, find.text('确认视频授权'));
    expect(find.byTooltip('关闭视频授权'), findsOneWidget);
    expect(transport.roomData['video_consent'], false);
    expect(find.text('连接暂时中断，请重试。已提交的操作会继续核对。'), findsWidgets);
    await capture(
      tester,
      'video-consent-error',
      'Submit episode video consent → request unavailable; dialog remains open',
    );
    transport.failingWrites.clear();
    consentPollGate.complete();
    await tester.pumpAndSettle();
    await tap(tester, find.text('确认视频授权'));
    expect(transport.roomData['video_consent'], true);
    await capture(
      tester,
      'video-consent-retry',
      'Retry consent → grant stored, return to preflight',
    );
    await tap(tester, find.byKey(const ValueKey('consult-location')));
    await capture(
      tester,
      'location-options',
      'Open current state selector → supported choices',
    );
    await tap(tester, find.text('New York (NY)').last);
    await capture(
      tester,
      'location-selected',
      'Choose New York → current location draft changes',
    );
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, 0);
    expect(find.text('当前专家暂不支持你选择的州，请确认实际所在地，或返回预约页重新安排。'), findsOneWidget);
    await capture(
      tester,
      'location-rejected',
      'Confirm unsupported current location → server blocks entry',
    );
    await tap(tester, find.byKey(const ValueKey('consult-location')));
    await tap(tester, find.text('California (CA)').last);
    transport.failingWrites.add(
      '/v1/care/appointments/service-appointment/location-check',
    );
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, 0);
    await capture(
      tester,
      'location-request-error',
      'Correct location then confirm → network failure, no room join',
    );
    transport.failingWrites.clear();
    transport.failingWrites.add(
      '/v1/care/appointments/service-appointment/room/join',
    );
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, 0);
    expect(find.byTooltip('关闭咨询确认'), findsOneWidget);
    await capture(
      tester,
      'join-request-error',
      'Location passes and room prepares; join unavailable → awaiting recovery',
    );
    transport.failingWrites.clear();
    await pollRoom(tester);
    expect(transport.connectionNumber, 1);
    expect(find.byTooltip('关闭咨询确认'), findsNothing);
    await capture(
      tester,
      'join-poll-recovered',
      'Actual room poll retries pending join → waiting room connected',
    );
    transport.roomData['video_consent'] = false;
    await pollRoom(tester);
    expect(find.text('开始咨询'), findsOneWidget);
    await capture(
      tester,
      'consent-revoked-in-room',
      'Server revokes video consent → media disconnected, preparation restored',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'inventory consultation loading failed read and closed preflight',
    (tester) async {
      await mount(tester);
      await bookingEntry(tester);
      const path = '/v1/care/appointments/service-appointment/room';
      final gate = Completer<void>();
      transport.readGates[path] = gate;
      await tester.tap(find.text('咨询前准备'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await capture(
        tester,
        'room-loading',
        'Booking preparation CTA → room initial request pending',
      );
      transport.failingReads.add(path);
      gate.complete();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'room-load-error',
        'Initial room request fails → retry state',
      );
      transport.failingReads.clear();
      await tap(tester, find.text('重试'));
      expect(find.text('开始咨询'), findsOneWidget);
      await capture(
        tester,
        'room-load-retry',
        'Retry room load → preparation ready',
      );
      await tap(tester, find.text('开始咨询'));
      await deviceReady(tester);
      await tap(tester, find.byTooltip('关闭设备检测'));
      await capture(
        tester,
        'device-check-dismissed',
        'Close passed device check → preparation, no join',
      );
      expect(transport.connectionNumber, 0);
      await tap(tester, find.text('开始咨询'));
      await deviceReady(tester);
      await tap(tester, find.text('继续确认'));
      await tap(tester, find.text('去授权'));
      await tap(tester, find.byTooltip('关闭视频授权'));
      await capture(
        tester,
        'video-consent-dismissed',
        'Close consent without granting → preflight still requires consent',
      );
      expect(transport.roomData['video_consent'], false);
      await tap(tester, find.byTooltip('关闭咨询确认'));
      await capture(
        tester,
        'preflight-dismissed',
        'Close preflight → preparation, no join',
      );
      expect(transport.connectionNumber, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory consultation current preflight feedback gaps', (
    tester,
  ) async {
    await mount(tester);
    await bookingEntry(tester);
    const readPath = '/v1/care/appointments/service-appointment/room';
    final initial = Completer<void>();
    transport.readGates[readPath] = initial;
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '咨询前准备'));
    await tester.tap(find.widgetWithText(OutlinedButton, '咨询前准备'));
    await tester.pump(const Duration(milliseconds: 100));
    await capture(
      tester,
      'current-room-loading',
      'Booking → consultation preparation, initial room read pending',
    );
    transport.failingReads.add(readPath);
    initial.complete();
    await tester.pumpAndSettle();
    await capture(
      tester,
      'current-room-load-error',
      'Initial room read fails → retry feedback',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('重试'));
    await tap(tester, find.text('开始咨询'));
    await deviceReady(tester);
    await tap(tester, find.text('继续确认'));
    await tap(tester, find.text('去授权'));
    await tap(tester, find.byKey(const ValueKey('room-video-consent')));
    final consentGate = Completer<void>();
    transport.readGates[readPath] = consentGate;
    transport.failingWrites.add('/v1/care/episodes/service-episode/consents');
    await tap(tester, find.text('确认视频授权'));
    expect(transport.roomData['video_consent'], false);
    await capture(
      tester,
      'current-video-consent-error',
      'Video consent submit fails → selected consent retained in dialog',
    );
    transport.failingWrites.clear();
    consentGate.complete();
    await tester.pumpAndSettle();
    await tap(tester, find.text('确认视频授权'));
    expect(transport.roomData['video_consent'], true);
    transport.failingWrites.add(
      '/v1/care/appointments/service-appointment/location-check',
    );
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, 0);
    await capture(
      tester,
      'current-location-request-error',
      'Confirm current location → request fails, entry remains blocked',
    );
    transport.failingWrites.clear();
    transport.failingWrites.add(
      '/v1/care/appointments/service-appointment/room/join',
    );
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, 0);
    await capture(
      tester,
      'current-join-request-error',
      'Location accepted → join fails, start dialog awaits recovery',
    );
    transport.failingWrites.clear();
    await pollRoom(tester);
    expect(transport.connectionNumber, 1);
    expect(find.byTooltip('关闭咨询确认'), findsNothing);
    // G02 already owns the connected-room image; keep the real recovery assertion.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory consultation current live leave route', (
    tester,
  ) async {
    await mount(tester);
    transport.roomData['video_consent'] = true;
    await roomEntry(tester);
    await enterReadyRoom(tester);
    // Waiting layout already captured by G01 current-before-outcome.
    await tap(tester, find.text('离开房间'));
    await capture(
      tester,
      'current-live-leave-confirmation',
      'Me → service → booking → preparation → passed checks → room → Leave',
    );
    await tap(tester, find.text('留在房间'));
    expect(router.state.uri.path, roomRoute);
    expect(transport.connectionNumber, 1);
    await tap(tester, find.text('离开房间'));
    await tap(tester, find.byTooltip('关闭离开确认'));
    expect(router.state.uri.path, roomRoute);
    expect(transport.connectionNumber, 1);
    transport.consultation(status: 'in_progress');
    await pollRoom(tester);
    await capture(
      tester,
      'current-live-active',
      'Stay and close confirmation both retain the room; expert joins → active consultation',
    );
    await tap(tester, find.text('离开房间'));
    await tap(tester, find.text('暂时离开'));
    // The production leave awaits endOfFrame before popping the room route.
    await tester.pumpAndSettle();
    await capture(
      tester,
      'current-live-left-booking',
      'Temporary leave → booking with ongoing consultation; re-entry remains available',
      route: bookingRoute,
    );
    expect(
      transport.requests.any(
        (r) => (r['path'] as String).endsWith('/room/end'),
      ),
      isFalse,
    );
    expect(
      transport.requests.any(
        (r) =>
            (r['path'] as String).endsWith('/room/presence') &&
            (r['body'] as Map)['presence'] == 'left',
      ),
      isTrue,
    );
    await tap(tester, find.widgetWithText(OutlinedButton, '返回咨询室'));
    expect(router.state.uri.path, roomRoute);
    expect(find.text('重新进入咨询室'), findsOneWidget);
    await capture(
      tester,
      'current-live-reentry-preparation',
      'Booking → return to consultation → preparation offers re-entry',
    );
    await tap(tester, find.text('重新进入咨询室'));
    await deviceReady(tester);
    await tap(tester, find.text('继续确认'));
    await tap(tester, find.text('确认并进入咨询室'));
    expect(transport.connectionNumber, 2);
    expect(find.text('离开房间'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // G01: one viewport per distinct outcome. Reuse identical entry/destination
  // evidence instead of multiplying captures by route, text scale or HTTP code.
  for (final outcome in [
    (
      name: 'technical',
      status: 'failed',
      reason: 'technical_failure',
      title: '视频连接未能继续',
    ),
    (
      name: 'no-show',
      status: 'no_show',
      reason: 'user_no_show',
      title: '这次咨询未能开始',
    ),
    (
      name: 'safety',
      status: 'note_pending',
      reason: 'safety_escalation',
      title: '本次咨询已结束',
    ),
    (
      name: 'completed',
      status: 'note_pending',
      reason: 'completed',
      title: '本次咨询已结束',
    ),
    (name: 'cancelled', status: 'note_pending', reason: null, title: '预约已取消'),
    (
      name: 'pending-record',
      status: 'note_pending',
      reason: null,
      title: '本次咨询已结束',
    ),
  ]) {
    for (final action
        in outcome.name == 'completed'
            ? ['primary']
            : ['primary', 'secondary']) {
      testWidgets(
        'inventory consultation current ${outcome.name} outcome onward routes $action',
        (tester) async {
          await mount(tester);
          transport.roomData['video_consent'] = true;
          await roomEntry(tester);
          if (outcome.name != 'no-show') await enterReadyRoom(tester);
          if (outcome.name == 'technical' && action == 'primary') {
            await capture(
              tester,
              'current-before-outcome',
              'Me → expert plan → my service → booking → preparation → device check → confirm entry',
            );
          }
          if (outcome.name == 'no-show') {
            expect(transport.connectionNumber, 0);
            transport.roomData['server_time'] = inventoryMomNow
                .add(const Duration(minutes: 20))
                .toIso8601String();
          }
          transport.consultation(
            status: outcome.status,
            roomStatus: 'closing',
            endReason: outcome.reason,
          );
          if (outcome.name == 'cancelled') {
            transport.appointment!['status'] = 'cancelled';
          }
          await pollRoom(tester);
          expect(find.text(outcome.title), findsOneWidget);
          if (action == 'primary') {
            await capture(
              tester,
              'current-${outcome.name}-outcome',
              outcome.name == 'no-show'
                  ? 'Me → service → booking → preparation without joining; attendance deadline passes → no-show result'
                  : 'Me → service → booking → preparation → device check → enter; server ${outcome.reason ?? outcome.name} → result',
            );
          }
          final unsuccessful = ['technical', 'no-show'].contains(outcome.name);
          final button = action == 'primary'
              ? (unsuccessful ? '重新预约' : '查看咨询总结')
              : (unsuccessful ? '返回妈妈主页' : '重新预约');
          final destination = button == '重新预约'
              ? bookingRoute
              : button == '返回妈妈主页'
              ? '/me'
              : '/services/appointments/service-appointment/summary';
          await tap(tester, find.text(button));
          expect(router.state.uri.path, destination);
          final destinations = [
            {'button': button, 'route': destination},
          ];
          if (outcome.name == 'technical' ||
              (outcome.name == 'safety' && action == 'primary')) {
            await capture(
              tester,
              button == '重新预约'
                  ? 'current-outcome-rebook'
                  : button == '返回妈妈主页'
                  ? 'current-outcome-home'
                  : 'current-outcome-summary',
              'Outcome → $button; shared destination for equivalent outcome CTAs',
              route: destination,
            );
          }
          final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
          if (output != null) {
            final file = File(
              '$output/outcome-current-actions/${outcome.name}-$action.json',
            );
            file.parent.createSync(recursive: true);
            file.writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({'outcome': outcome.name, 'source': 'test/goldens/ui_inventory/consultation-journey-current-${outcome.name}-outcome-393.png', 'destinations': destinations, 'evidence': 'Actual visible CTA taps and production router assertions; isolated HTTP/device boundaries'})}\n',
            );
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
