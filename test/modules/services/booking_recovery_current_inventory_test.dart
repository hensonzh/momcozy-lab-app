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
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/appointment_cancel_dialog.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/service_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
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

        session: session,
        supportsSessionAutoRefresh: false,
        now: () => transport.clock,
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
        'test/goldens/ui_inventory/booking-recovery-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/booking-recovery-current-$state-$variant.png',
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
          'test/modules/services/booking_recovery_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/booking-recovery-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const holds = '/v1/care/episodes/service-episode/holds';
  const confirm = '/v1/care/appointments/service-appointment/confirm';
  const cancel = '/v1/care/appointments/service-appointment/cancel';
  const read = '/v1/care/appointments/service-appointment';
  Future<void> enter(WidgetTester tester, String chain) async {
    await mount(tester);
    await capture(
      tester,
      '$chain-home',
      'More → Me → owned service',
      route: '/me',
    );
    await tap(tester, find.text('预约咨询'));
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('California (CA)').last);
    await tap(tester, find.text('我需要的是哺乳或喂养相关的 IBCLC 咨询'));
    await tap(tester, find.text('目前没有上述紧急情况'));
    await tap(tester, find.text('继续选择时间'));
    await capture(
      tester,
      '$chain-slots',
      'Complete precheck → available times',
    );
  }

  Future<void> finish(WidgetTester tester, String chain) async {
    await tap(tester, find.text('返回'));
    await capture(
      tester,
      '$chain-home-return',
      'Booking Back → Me',
      route: '/me',
    );
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> hold(WidgetTester tester) => tap(tester, find.text('60 分钟'));
  Finder cancelText(String text) => find.descendant(
    of: find.byType(AppointmentCancelDialog),
    matching: find.text(text),
  );
  for (final compact in [false, true]) {
    testWidgets('current booking hold business rejection recovery $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'business');
      for (final code in [
        'slot_unavailable',
        'region_unavailable',
        'service_not_bookable',
        'appointment_exists',
        'hold_expired',
        'eligibility_required',
      ]) {
        transport.codes[holds] = code;
        await hold(tester);
        await capture(
          tester,
          'hold-$code',
          'Select time → HTTP 409 business rejection: $code',
        );
        expect(find.byType(BookingSelectionDialog), findsNothing);
        expect(transport.appointment, isNull);
        expect(find.text('重试上次提交'), findsNothing);
        transport.codes.clear();
        if (code == 'eligibility_required') {
          await tap(tester, find.text('开始确认'));
          await capture(
            tester,
            'eligibility-reopened',
            'Expired precheck → Start confirmation with prior choices retained',
          );
          await tap(tester, find.text('继续选择时间'));
          await capture(
            tester,
            'eligibility-restored',
            'Recheck succeeds → time picker recovered',
          );
        }
      }
      await hold(tester);
      await capture(
        tester,
        'business-held',
        'After rejected attempts → hold accepted',
      );
      await tap(tester, find.text('重新选择'));
      await capture(
        tester,
        'business-released',
        'Reselect accepted held time → cancellation succeeds and picker restored',
      );
      await finish(tester, 'business');
    });
    testWidgets(
      'current booking hold expiry and latest confirmation $compact',
      (tester) async {
        narrow = compact;
        await enter(tester, 'expiry');
        await hold(tester);
        await capture(
          tester,
          'expiry-held',
          'Hold accepted → ten-minute review',
        );
        transport.clock = transport.clock.add(const Duration(minutes: 11));
        await tester.pump(const Duration(seconds: 1));
        await capture(
          tester,
          'hold-timeout',
          'Injected device clock passes hold expiry → reselect notice',
        );
        expect(find.text('确认预约'), findsNothing);
        final count = transport.requests.length;
        await tap(tester, find.text('重新选择'));
        expect(transport.requests.length, count);
        await capture(
          tester,
          'timeout-reselected',
          'Reselect elapsed hold → picker without cancel mutation',
        );
        await hold(tester);
        await capture(
          tester,
          'after-timeout-held',
          'Select time again → fresh hold',
        );
        transport.codes[confirm] = 'hold_expired';
        await tap(tester, find.text('确认预约'));
        await capture(
          tester,
          'confirm-hold-expired',
          'Confirm rejected with hold_expired → query latest action',
        );
        transport.codes.clear();
        transport.appointment!['status'] = 'expired';
        await tap(tester, find.text('查询最新预约'));
        await capture(
          tester,
          'latest-expired',
          'Query latest returns expired → reselect remains',
        );
        await tap(tester, find.text('重新选择'));
        await hold(tester);
        transport.codes[confirm] = 'version_conflict';
        await tap(tester, find.text('确认预约'));
        await capture(
          tester,
          'confirm-version-conflict',
          'New hold confirmation HTTP 409 → query latest state',
        );
        transport.codes.clear();
        transport.appointment!['status'] = 'confirmed';
        transport.appointment!['version'] = 2;
        await tap(tester, find.text('查询最新预约'));
        await capture(
          tester,
          'latest-confirmed',
          'Query latest reveals confirmed → continue intake action',
        );
        await tap(tester, find.text('继续填写信息采集表'));
        await capture(
          tester,
          'latest-confirmed-intake',
          'Continue from synchronized confirmation → intake',
          route: '/services/appointments/service-appointment/intake',
        );
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'latest-confirmed-return',
          'Unchanged intake Back → confirmed appointment',
        );
        await finish(tester, 'expiry');
      },
    );
    testWidgets(
      'current confirmed appointment cancellation and state recovery $compact',
      (tester) async {
        narrow = compact;
        await enter(tester, 'cancel');
        await hold(tester);
        await tap(tester, find.text('确认预约'));
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'cancel-confirmed',
          'Confirm → intake → Back to confirmed detail',
        );
        await tap(tester, find.text('取消预约'));
        await capture(
          tester,
          'cancel-open',
          'Cancel appointment → confirmation dialog',
        );
        await tap(tester, cancelText('保留预约'));
        await capture(
          tester,
          'cancel-retained',
          'Keep appointment → confirmed detail',
        );
        await tap(tester, find.text('取消预约'));
        transport.writeGate = Completer<void>();
        await tap(tester, cancelText('确认取消'));
        await capture(
          tester,
          'cancel-pending',
          'Confirm cancellation → request pending and dismissal disabled',
        );
        await router.routerDelegate.popRoute();
        await settle(tester);
        expect(find.byType(AppointmentCancelDialog), findsOneWidget);
        transport.failingWrites.add(cancel);
        transport.writeGate!.complete();
        transport.writeGate = null;
        await settle(tester);
        await capture(
          tester,
          'cancel-uncertain',
          'Cancellation HTTP 503 → uncertain, retry or query latest',
        );
        transport.failingWrites.clear();
        transport.readGates[read] = Completer<void>();
        await tap(tester, cancelText('核对预约状态'));
        await capture(
          tester,
          'cancel-query-pending',
          'Query latest appointment → pending',
        );
        transport.failingReads.add(read);
        transport.readGates.remove(read)!.complete();
        await settle(tester);
        await capture(
          tester,
          'cancel-query-error',
          'Query HTTP 503 → uncertainty retained',
        );
        transport.failingReads.clear();
        transport.appointment!['status'] = 'in_progress';
        await tap(tester, cancelText('核对预约状态'));
        await capture(
          tester,
          'cancel-no-longer-allowed',
          'Query latest in_progress → cannot cancel, return action',
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, '确认取消'),
              )
              .onPressed,
          isNull,
        );
        await tap(tester, cancelText('返回预约'));
        await capture(
          tester,
          'cancel-in-progress-return',
          'Return → refreshed in-progress appointment detail',
        );
        await finish(tester, 'cancel-in-progress');
      },
    );
    testWidgets('current confirmed cancellation retry succeeds $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'cancel-retry');
      await hold(tester);
      await tap(tester, find.text('确认预约'));
      await tap(tester, find.text('返回'));
      await tap(tester, find.text('取消预约'));
      await capture(
        tester,
        'cancel-retry-open',
        'Confirmed appointment → cancellation dialog',
      );
      transport.failingWrites.add(cancel);
      await tap(tester, cancelText('确认取消'));
      final request = Map<String, Object?>.from(transport.requests.last);
      await capture(
        tester,
        'cancel-retry-error',
        'Cancellation HTTP 503 → retry original operation',
      );
      transport.failingWrites.clear();
      await tap(tester, cancelText('重试取消'));
      expect(transport.requests.last['body'], request['body']);
      expect(transport.appointment?['status'], 'cancelled');
      await capture(
        tester,
        'cancel-complete-home',
        'Retry cancellation accepted → automatic return to Me',
        route: '/me',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _BookingTransport extends ServiceInventoryTransport {
  _BookingTransport() {
    ownPlan();
  }
  DateTime clock = inventoryMomNow;
  final codes = <String, String>{};
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final data = await super.getJson(path, query: query);
    return data.containsKey('server_time')
        ? {...data, 'server_time': clock.toIso8601String()}
        : data;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (codes[path] case final code?) {
      requests.add({
        'path': path,
        'body': Map<String, Object?>.from(body),
        'headers': Map<String, String>.from(headers),
      });
      mutationPaths.add(path);
      if (code == 'eligibility_required') {
        bookingEligibility = null;
      }
      throw ApiHttpException.fromBody({
        'http_status': 409,
        'body': {
          'error': {'code': code},
        },
      });
    }
    final data = await super.postJson(path, body: body, headers: headers);
    if (path.endsWith('/holds')) {
      data['hold_expires_at'] = clock
          .add(const Duration(minutes: 10))
          .toIso8601String();
    }
    if (path.endsWith('/booking-eligibility')) {
      data['expires_at'] = clock
          .add(const Duration(hours: 1))
          .toIso8601String();
    }
    return data;
  }
}
