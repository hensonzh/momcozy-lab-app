import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/lactation_panel.dart';
import 'package:momcozy_flutter_app/modules/mom/application/lactation_controller.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  late MomInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  Future<void> mount(
    WidgetTester tester, {
    void Function(MomInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double scale = 1,
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = MomInventoryTransport();
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
        'assets/images/mom/milk-hero.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/more');
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
        scrollable: find.byType(Scrollable).last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> verifyState(
    WidgetTester tester, {
    String route = '/me/lactation',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
  }

  Future<void> closePanel(WidgetTester tester) async {
    final close = find.byTooltip('Close feeding and pumping records');
    if (close.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        close,
        -250,
        scrollable: find
            .descendant(
              of: find.byType(LactationPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tap(tester, close);
  }

  LactationDraft draft(WidgetTester tester) => tester
      .widget<LactationPanel>(find.byType(LactationPanel))
      .controller
      .draft!;
  Finder measurement(LactationMethod method) =>
      find.byKey(ValueKey('lactation-measurement-${method.name}'));
  Future<void> input(WidgetTester tester, Finder target, String text) async {
    await tester.ensureVisible(target);
    await tester.enterText(target, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> editSaved(WidgetTester tester) => tap(
    tester,
    find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
  );

  // The SDK paints clock numbers on a canvas. Tap measured dial positions,
  // then inspect its selectedTime; never call the selection callbacks directly.
  final picker = find.byKey(const ValueKey('momcozy-time-picker'));
  Finder sdkControl(String name) => find.descendant(
    of: picker,
    matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == name),
  );
  TimeOfDay dialValue(WidgetTester tester) =>
      (tester.widget(sdkControl('_Dial')) as dynamic).selectedTime as TimeOfDay;
  String dialMode(WidgetTester tester) =>
      (tester.widget(sdkControl('_Dial')) as dynamic).hourMinuteMode.toString();
  Future<void> selectDial(WidgetTester tester, int value, int divisions) async {
    final rect = tester.getRect(sdkControl('_Dial'));
    final theta = 2 * math.pi * value / divisions;
    final radius = rect.shortestSide * .38;
    await tester.tapAt(
      rect.center + Offset(math.sin(theta), -math.cos(theta)) * radius,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final width in [393.0, 320.0]) {
    testWidgets('inventory milk clock dial ${width.toInt()}/1x', (
      tester,
    ) async {
      await mount(tester, width: width, scale: 1);
      await verifyState(tester, route: '/more');
      router.push('/me/lactation?create=1');
      await tester.pumpAndSettle();
      await input(tester, measurement(LactationMethod.pump), '120');
      await verifyState(tester);
      Future<void> openPicker() => tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      await openPicker();
      final strings = MaterialLocalizations.of(tester.element(picker));
      Finder action(String text) =>
          find.descendant(of: picker, matching: find.text(text));
      expect(dialValue(tester), const TimeOfDay(hour: 16, minute: 0));
      expect(dialMode(tester), endsWith('.hour'));
      await verifyState(tester);
      await selectDial(tester, 9, 12);
      expect(dialValue(tester), const TimeOfDay(hour: 21, minute: 0));
      expect(dialMode(tester), endsWith('.minute'));
      await verifyState(tester);
      await selectDial(tester, 45, 60);
      expect(dialValue(tester), const TimeOfDay(hour: 21, minute: 45));
      await verifyState(tester);
      await tap(tester, sdkControl('_DialHourControl'));
      expect(dialMode(tester), endsWith('.hour'));
      await verifyState(tester);
      await selectDial(tester, 11, 12);
      expect(dialValue(tester), const TimeOfDay(hour: 23, minute: 45));
      await verifyState(tester);
      await selectDial(tester, 20, 60);
      expect(dialValue(tester), const TimeOfDay(hour: 23, minute: 20));
      await verifyState(tester);
      await tap(tester, action(strings.anteMeridiemAbbreviation));
      expect(dialValue(tester), const TimeOfDay(hour: 11, minute: 20));
      await verifyState(tester);
      await tap(tester, action(strings.okButtonLabel));
      expect(draft(tester).occurredAt.hour, 11);
      expect(draft(tester).occurredAt.minute, 20);
      await verifyState(tester);
      await tap(tester, find.text('Save this record'));
      expect(transport.records.single['version'], 1);
      await verifyState(tester);
      await editSaved(tester);
      await openPicker();
      expect(dialValue(tester), const TimeOfDay(hour: 11, minute: 20));
      await verifyState(tester);
      await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
      await verifyState(tester);
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      await input(tester, fields.first, '00');
      await input(tester, fields.last, '60');
      await tap(tester, action(strings.okButtonLabel));
      expect(picker, findsOneWidget);
      expect(action(strings.invalidTimeLabel), findsWidgets);
      expect(draft(tester).occurredAt.hour, 11);
      expect(draft(tester).occurredAt.minute, 20);
      await verifyState(tester);
      if (width < 360) {
        final horizontal = find.descendant(
          of: picker,
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        );
        expect(horizontal, findsOneWidget);
        final position = tester.state<ScrollableState>(horizontal).position;
        expect(
          position.maxScrollExtent,
          0,
          reason:
              'English picker controls should fit without horizontal scrolling',
        );
        expect(action(strings.okButtonLabel).hitTestable(), findsOneWidget);
        await verifyState(tester);
        await verifyState(tester);
      }
      await input(tester, fields.first, '12');
      await input(tester, fields.last, '00');
      await tap(tester, find.byTooltip(strings.dialModeButtonLabel));
      expect(dialValue(tester), const TimeOfDay(hour: 0, minute: 0));
      await verifyState(tester);
      await tap(tester, action(strings.postMeridiemAbbreviation));
      expect(dialValue(tester), const TimeOfDay(hour: 12, minute: 0));
      await verifyState(tester);
      await tap(tester, sdkControl('_DialMinuteControl'));
      expect(dialMode(tester), endsWith('.minute'));
      await verifyState(tester);
      await tap(tester, action(strings.okButtonLabel));
      expect(draft(tester).occurredAt.hour, 12);
      expect(draft(tester).occurredAt.minute, 0);
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(transport.records.single['version'], 2);
      await verifyState(tester);
      await editSaved(tester);
      await openPicker();
      await selectDial(tester, 3, 12);
      expect(dialValue(tester), const TimeOfDay(hour: 15, minute: 0));
      await verifyState(tester);
      await tap(tester, action(strings.cancelButtonLabel));
      expect(draft(tester).occurredAt.hour, 12);
      expect(draft(tester).occurredAt.minute, 0);
      await verifyState(tester);
      await closePanel(tester);
      await verifyState(tester);
      await tap(tester, find.text('Leave'));
      expect(transport.records.single['version'], 2);
      await verifyState(tester, route: '/more');
      await tester.pumpAndSettle();
      await verifyState(tester, route: '/more');
    });
  }
}
