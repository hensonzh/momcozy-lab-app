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
        'test/goldens/ui_inventory/booking-selection-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/booking-selection-current-$state-$variant.png',
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
          'test/modules/services/booking_selection_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/booking-selection-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  const availability = '/v1/care/episodes/service-episode/availability';
  const holds = '/v1/care/episodes/service-episode/holds';
  const confirm = '/v1/care/appointments/service-appointment/confirm';
  const cancel = '/v1/care/appointments/service-appointment/cancel';
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

  Future<void> writeFailure(WidgetTester tester, String path) async {
    transport.failingWrites.add(path);
    transport.writeGate!.complete();
    transport.writeGate = null;
    await settle(tester);
  }

  for (final compact in [false, true]) {
    testWidgets('current booking provider and date selection $compact', (
      tester,
    ) async {
      narrow = compact;
      await enter(tester, 'selection');
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await capture(
        tester,
        'provider-menu',
        'Provider dropdown → two available experts',
      );
      transport.readGates[availability] = Completer<void>();
      await tap(tester, find.text('East Coast IBCLC').last);
      await capture(
        tester,
        'provider-loading',
        'Select east coast expert → new timezone and times pending',
      );
      expect(transport.queries.last['provider_id'], 'inventory-east');
      transport.readGates.remove(availability)!.complete();
      await settle(tester);
      await capture(
        tester,
        'provider-selected',
        'Availability loaded in America/New_York',
      );
      expect(find.text('13:00 – 14:00 EDT'), findsOneWidget);
      await tap(tester, find.text('2026-09-13'));
      final picker = find.byType(DatePickerDialog);
      final strings = MaterialLocalizations.of(tester.element(picker));
      Finder button(String label) =>
          find.descendant(of: picker, matching: find.text(label));
      final field = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      Future<void> input(String value) async {
        await tester.enterText(field, value);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
      }

      expect(
        tester.widget<DatePickerDialog>(picker).firstDate,
        DateTime(2026, 9, 13),
      );
      expect(
        tester.widget<DatePickerDialog>(picker).lastDate,
        DateTime(2026, 12, 12),
      );
      await capture(
        tester,
        'date-open',
        'Open date picker; large text uses input only',
      );
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.nextMonthTooltip));
        await capture(
          tester,
          'date-next-month',
          'Next month → October calendar',
        );
        await tap(tester, find.byTooltip(strings.previousMonthTooltip));
        await tap(
          tester,
          find.text(strings.formatMonthYear(DateTime(2026, 9))),
        );
        await capture(
          tester,
          'date-year-menu',
          'Calendar header → year selection',
        );
        await tap(
          tester,
          find.descendant(
            of: find.byType(YearPicker),
            matching: find.text(strings.formatYear(DateTime(2026))),
          ),
        );
        await tap(
          tester,
          find.descendant(
            of: find.byType(CalendarDatePicker),
            matching: find.text('14'),
          ),
        );
        await capture(
          tester,
          'date-day-selected',
          'Select September 14, awaiting confirmation',
        );
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      }
      await input('invalid');
      await tap(tester, button(strings.okButtonLabel));
      await capture(
        tester,
        'date-invalid',
        'Confirm malformed date → validation error',
      );
      await input(strings.formatCompactDate(DateTime(2026, 9, 12)));
      await tap(tester, button(strings.okButtonLabel));
      await capture(
        tester,
        'date-before-today',
        'Confirm past date → out-of-range error',
      );
      await input(strings.formatCompactDate(DateTime(2026, 12, 13)));
      await tap(tester, button(strings.okButtonLabel));
      await capture(
        tester,
        'date-after-window',
        'Confirm beyond 90 days → out-of-range error',
      );
      await tap(tester, button(strings.cancelButtonLabel));
      await capture(
        tester,
        'date-cancelled',
        'Cancel date input → prior September 13 preserved',
      );
      await tap(tester, find.text('2026-09-13'));
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      }
      await input(strings.formatCompactDate(DateTime(2026, 9, 14)));
      await capture(
        tester,
        'date-valid-input',
        'Enter tomorrow → valid date draft',
      );
      await tap(tester, button(strings.okButtonLabel));
      expect(transport.queries.last['date'], '2026-09-14');
      await capture(
        tester,
        'date-applied',
        'Confirm date → September 14 availability',
      );
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await tap(tester, find.text('Test IBCLC').last);
      expect(transport.queries.last['date'], '2026-09-14');
      expect(transport.queries.last['provider_id'], 'inventory-ibclc');
      await capture(
        tester,
        'provider-return',
        'Switch back to Pacific expert → keep date and change timezone',
      );
      await finish(tester, 'selection');
    });
    testWidgets(
      'current booking hold reselect and confirmation recovery $compact',
      (tester) async {
        narrow = compact;
        await enter(tester, 'hold');
        transport.writeGate = Completer<void>();
        await tap(tester, find.text('60 分钟'));
        await capture(
          tester,
          'hold-pending',
          'Select available time → hold request pending',
        );
        final first = Map<String, Object?>.from(transport.requests.last);
        expect(first['path'], holds);
        await writeFailure(tester, holds);
        await capture(
          tester,
          'hold-error',
          'Hold HTTP 503 → unresolved submission with retry',
        );
        transport.failingWrites.clear();
        await tap(tester, find.text('重试上次提交'));
        expect(transport.requests.last['body'], first['body']);
        expect(transport.requests.last['headers'], first['headers']);
        expect(find.byType(BookingSelectionDialog), findsOneWidget);
        await capture(
          tester,
          'held-review',
          'Retry same idempotency key → held appointment review',
        );
        await tap(tester, find.text('提前 15 分钟提醒我'));
        await capture(tester, 'reminder-selected', 'Enable reminder draft');
        await tap(tester, find.text('提前 15 分钟提醒我'));
        await capture(tester, 'reminder-cleared', 'Disable reminder draft');
        await tap(tester, find.byTooltip('关闭预约时间确认'));
        expect(transport.appointment?['status'], 'held');
        await capture(
          tester,
          'held-closed',
          'Close review → time remains held; provider and date disabled',
        );
        await tap(tester, find.text('查看所选时间'));
        await capture(
          tester,
          'held-reopened',
          'View selected time → reopen review',
        );
        transport.writeGate = Completer<void>();
        await tap(tester, find.text('重新选择'));
        await capture(
          tester,
          'reselect-pending',
          'Reselect → cancel held time pending',
        );
        await writeFailure(tester, cancel);
        await capture(
          tester,
          'reselect-error',
          'Cancel hold HTTP 503 → retry previous submission',
        );
        transport.failingWrites.clear();
        await tap(tester, find.text('重试上次提交').last);
        expect(transport.appointment?['status'], 'cancelled');
        expect(find.byType(BookingSelectionDialog), findsNothing);
        await capture(
          tester,
          'reselect-restored',
          'Retry cancel → review closes and time selection restored',
        );
        await tap(tester, find.text('60 分钟'));
        await capture(
          tester,
          'second-held',
          'Select again → fresh hold review',
        );
        final newHold = transport.requests.last;
        expect(newHold['headers'], isNot(first['headers']));
        transport.writeGate = Completer<void>();
        await tap(tester, find.text('确认预约'));
        await capture(
          tester,
          'confirm-pending',
          'Confirm held appointment → expected-version request pending',
        );
        final confirmRequest = Map<String, Object?>.from(
          transport.requests.last,
        );
        expect(confirmRequest['path'], confirm);
        await router.routerDelegate.popRoute();
        await settle(tester);
        expect(find.byType(BookingSelectionDialog), findsOneWidget);
        await writeFailure(tester, confirm);
        await capture(
          tester,
          'confirm-error',
          'Pending Back blocked; confirm HTTP 503 → retry',
        );
        transport.failingWrites.clear();
        await tap(tester, find.text('重试上次提交').last);
        expect(transport.requests.last['body'], confirmRequest['body']);
        expect(transport.appointment?['status'], 'confirmed');
        await capture(
          tester,
          'confirmed-intake',
          'Retry confirmation → real information intake page',
          route: '/services/appointments/service-appointment/intake',
        );
        await tap(tester, find.text('返回'));
        await capture(
          tester,
          'confirmed-detail',
          'Return from unchanged intake → confirmed booking detail',
        );
        await finish(tester, 'hold');
      },
    );
  }
}

class _BookingTransport extends ServiceInventoryTransport {
  _BookingTransport() {
    ownPlan();
  }
  final queries = <Map<String, Object?>>[];
  Map<String, Object?> get east => {
    ...provider,
    'user_id': 'inventory-east',
    'display_name': 'East Coast IBCLC',
    'timezone': 'America/New_York',
  };
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path.endsWith('/availability')) {
      queries.add(Map<String, Object?>.from(query));
    }
    final data = await super.getJson(path, query: query);
    if (path.endsWith('/booking')) {
      return {
        ...data,
        'providers': [provider, east],
      };
    }
    if (path.endsWith('/availability') &&
        query['provider_id'] == 'inventory-east') {
      return {
        ...data,
        'provider_id': 'inventory-east',
        'timezone': 'America/New_York',
      };
    }
    return data;
  }
}
