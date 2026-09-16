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
import 'package:momcozy_flutter_app/modules/services/presentation/booking_flow_dialogs.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/service_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late _BookingTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  var narrow = false;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_BookingTransport)? prepare,
    bool loading = false,
  }) async {
    previous = null;
    variant = narrow ? '320-2x' : '393-1x';
    tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(narrow ? 320 : 393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _BookingTransport();
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
        agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
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
    // Visit the lazy service section through scrolling, let its data and button
    // animations settle, then return to the top before the entry screenshot.
    final homeScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('服务进度 ›'),
      250,
      scrollable: homeScroll,
    );
    await tester.pumpAndSettle();
    await tester.drag(homeScroll, const Offset(0, 10000));
    await tester.pumpAndSettle();
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

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    if (transport.readGates.values.any((gate) => !gate.isCompleted) ||
        (transport.writeGate != null && !transport.writeGate!.isCompleted) ||
        find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 10000));
      await settle(tester);
    }
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/services/episodes/service-episode/booking',
  }) async {
    // A room close awaits endOfFrame before popping. Flush that deferred
    // navigation and settle its transition before recording the returned page.
    await settle(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/booking-precheck-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/booking-precheck-current-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Me bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test':
          'test/modules/services/booking_precheck_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/booking-precheck-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const booking = '/v1/care/episodes/service-episode/booking';
  const eligibility = '/v1/care/episodes/service-episode/booking-eligibility';
  const availability = '/v1/care/episodes/service-episode/availability';
  const suitable = '我需要的是哺乳或喂养相关的 IBCLC 咨询';
  Future<void> chooseRegion(WidgetTester tester, String label) async {
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text(label).last);
  }

  void expectContinue(WidgetTester tester, bool enabled) {
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '继续选择时间'),
    );
    expect(button.onPressed != null, enabled);
  }

  Future<void> closeAndBack(WidgetTester tester, String chain) async {
    await tap(tester, find.text('返回'));
    await capture(
      tester,
      '$chain-home-return',
      'Booking Back → Me',
      route: '/me',
    );
    await tester.pumpWidget(const SizedBox());
  }

  for (final compact in [false, true]) {
    testWidgets('current booking precheck controls and recovery $compact', (
      tester,
    ) async {
      narrow = compact;
      await mount(tester);
      await capture(
        tester,
        'controls-home',
        'More → Me → owned plan',
        route: '/me',
      );
      await tester.scrollUntilVisible(
        find.text('预约咨询'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      transport.readGates[booking] = Completer<void>();
      await tap(tester, find.text('预约咨询'));
      await capture(
        tester,
        'context-loading',
        'Book consultation → booking context pending',
      );
      transport.failingReads.add(booking);
      transport.readGates.remove(booking)!.complete();
      await settle(tester);
      await capture(
        tester,
        'context-error',
        'Booking context returns HTTP 503',
      );
      transport.failingReads.remove(booking);
      await tap(tester, find.text('重试'));
      expect(find.byType(BookingPrecheckDialog), findsOneWidget);
      await capture(
        tester,
        'initial',
        'Retry booking context → automatic precheck',
      );
      expectContinue(tester, false);
      await tap(tester, find.byTooltip('关闭预约前确认'));
      await capture(
        tester,
        'closed',
        'Close precheck → start confirmation card',
      );
      await tap(tester, find.text('开始确认'));
      await capture(tester, 'reopened', 'Start confirmation → blank precheck');
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await capture(
        tester,
        'region-menu',
        'Current state dropdown → CA / NY / TX choices',
      );
      await tap(tester, find.text('New York (NY)').last);
      await capture(
        tester,
        'region-unsupported',
        'Select NY → unsupported region notice',
      );
      expectContinue(tester, false);
      await chooseRegion(tester, 'California (CA)');
      await capture(
        tester,
        'region-supported',
        'Select CA → suitable service region',
      );
      await tap(tester, find.text(suitable));
      await capture(
        tester,
        'suitable',
        'Check lactation or feeding consultation suitability',
      );
      expectContinue(tester, false);
      await tap(tester, find.text('有，或我不确定'));
      await capture(
        tester,
        'emergency-help',
        'Select emergency or uncertain → urgent help notice',
      );
      expectContinue(tester, false);
      await tap(tester, find.text('目前没有上述紧急情况'));
      await capture(tester, 'ready', 'Select no emergency → continue enabled');
      expectContinue(tester, true);
      await tap(tester, find.text(suitable));
      await capture(
        tester,
        'suitable-cleared',
        'Uncheck service suitability → continue disabled',
      );
      expectContinue(tester, false);
      await tap(tester, find.text(suitable));
      transport.writeGate = Completer<void>();
      await tap(tester, find.text('继续选择时间'));
      await capture(
        tester,
        'submit-pending',
        'Continue → eligibility request pending; controls disabled',
      );
      expect(transport.requests.last['path'], eligibility);
      expect(transport.requests.last['body'], {
        'region': 'CA',
        'service_suitable': true,
        'emergency_status': 'clear',
      });
      await router.routerDelegate.popRoute();
      await settle(tester);
      expect(find.byType(BookingPrecheckDialog), findsOneWidget);
      transport.failingWrites.add(eligibility);
      transport.writeGate!.complete();
      transport.writeGate = null;
      await settle(tester);
      await capture(
        tester,
        'submit-error',
        'Pending back blocked; eligibility HTTP 503 → retryable notice',
      );
      expect(find.text('暂时无法确认，请检查网络后重试。'), findsOneWidget);
      transport.failingWrites.clear();
      for (final reason in [
        'emergency_help',
        'service_unsuitable',
        'region_not_supported',
      ]) {
        transport.rejection = reason;
        await tap(tester, find.text('继续选择时间'));
        await capture(
          tester,
          'server-$reason',
          'Continue → server ineligible: $reason',
        );
        expect(find.byType(BookingPrecheckDialog), findsOneWidget);
      }
      transport.rejection = null;
      await tap(tester, find.text('继续选择时间'));
      expect(find.byType(BookingPrecheckDialog), findsNothing);
      await capture(
        tester,
        'accepted-slots',
        'Retry accepted → provider, date and available/occupied times',
      );
      expect(
        transport.requests.where((r) => r['path'] == eligibility).length,
        5,
      );
      expect(transport.appointment, isNull);
      await closeAndBack(tester, 'controls');
    });
    testWidgets(
      'current booking precheck availability loading and retry $compact',
      (tester) async {
        narrow = compact;
        await mount(tester);
        await capture(
          tester,
          'availability-home',
          'More → Me → owned plan',
          route: '/me',
        );
        await tap(tester, find.text('预约咨询'));
        await chooseRegion(tester, 'California (CA)');
        await tap(tester, find.text(suitable));
        await tap(tester, find.text('目前没有上述紧急情况'));
        await capture(
          tester,
          'availability-ready',
          'Complete region, suitability and risk inputs',
        );
        transport.readGates[availability] = Completer<void>();
        await tap(tester, find.text('继续选择时间'));
        await capture(
          tester,
          'availability-pending',
          'Eligibility accepted → availability pending; dialog remains waiting',
        );
        expect(transport.bookingEligibility?['eligible'], true);
        await router.routerDelegate.popRoute();
        await settle(tester);
        expect(find.byType(BookingPrecheckDialog), findsOneWidget);
        transport.failingReads.add(availability);
        transport.readGates.remove(availability)!.complete();
        await settle(tester);
        expect(find.byType(BookingPrecheckDialog), findsNothing);
        await capture(
          tester,
          'availability-error',
          'Availability HTTP 503 → picker with retry error',
        );
        transport.failingReads.clear();
        transport.emptySlots = true;
        transport.readGates[availability] = Completer<void>();
        await tap(tester, find.text('重试'));
        await capture(
          tester,
          'availability-retry-pending',
          'Retry availability → picker loading spinner',
        );
        transport.readGates.remove(availability)!.complete();
        await settle(tester);
        await capture(
          tester,
          'availability-empty',
          'Availability succeeds with no slots',
        );
        expect(find.text('暂无可选时间'), findsOneWidget);
        transport.emptySlots = false;
        await tap(tester, find.byTooltip('刷新预约'));
        await capture(
          tester,
          'availability-restored',
          'Refresh booking → available and occupied times',
        );
        final before = transport.requests.length;
        await tap(tester, find.text('60 分钟 · 已占用'));
        expect(transport.requests.length, before);
        await capture(
          tester,
          'occupied-disabled',
          'Tap occupied time → no hold request and unchanged picker',
        );
        await closeAndBack(tester, 'availability');
      },
    );
  }
}

class _BookingTransport extends ServiceInventoryTransport {
  _BookingTransport() {
    ownPlan();
  }
  String? rejection;
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final result = await super.postJson(path, body: body, headers: headers);
    if (path.endsWith('/booking-eligibility') && rejection != null) {
      return bookingEligibility = {
        ...result,
        'eligible': false,
        'reason': rejection,
      };
    }
    return result;
  }
}
