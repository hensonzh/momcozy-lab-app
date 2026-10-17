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

  LactationController controller(WidgetTester tester) =>
      tester.widget<LactationPanel>(find.byType(LactationPanel)).controller;
  Future<void> editSaved(WidgetTester tester) => tap(
    tester,
    find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
  );

  for (final narrow in [false, true]) {
    testWidgets('inventory milk validation ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await verifyState(tester, route: '/more');
      router.push('/me/lactation?create=1');
      await tester.pumpAndSettle();
      await verifyState(tester);
      for (final item in [
        ('negative', '-1', 'volume_ml', 'out_of_range'),
        ('above-limit', '2001', 'volume_ml', 'out_of_range'),
        ('not-number', 'abc', 'measurement', 'invalid_number'),
        ('not-finite', 'NaN', 'volume_ml', 'out_of_range'),
      ]) {
        await input(tester, measurement(LactationMethod.pump), item.$2);
        expect(controller(tester).validationErrors, isEmpty);
        await tap(tester, find.text('Save this record'));
        expect(controller(tester).validationErrors, {item.$3: item.$4});
        expect(transport.records, isEmpty);
        await verifyState(tester);
      }
      await input(tester, measurement(LactationMethod.pump), '0');
      await verifyState(tester);
      await tap(tester, find.text('Save this record'));
      expect((transport.records.single['observation'] as Map)['volume_ml'], 0);
      await verifyState(tester);
      await editSaved(tester);
      await input(tester, measurement(LactationMethod.pump), '2000');
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(
        (transport.records.single['observation'] as Map)['volume_ml'],
        2000,
      );
      expect(transport.records.single['version'], 2);
      await verifyState(tester);
      await editSaved(tester);
      await tap(tester, find.text('Nursing'));
      expect(draft(tester).measurement, isEmpty);
      await verifyState(tester);
      for (final item in [
        ('negative', '-1', 'duration_minutes', 'out_of_range'),
        ('above-limit', '241', 'duration_minutes', 'out_of_range'),
        ('fraction', '1.5', 'measurement', 'invalid_number'),
      ]) {
        await input(tester, measurement(LactationMethod.nurse), item.$2);
        await tap(tester, find.text('Save changes'));
        expect(controller(tester).validationErrors, {item.$3: item.$4});
        expect(transport.records.single['version'], 2);
        await verifyState(tester);
      }
      await input(tester, measurement(LactationMethod.nurse), '240');
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(
        (transport.records.single['observation'] as Map)['duration_minutes'],
        240,
      );
      expect(transport.records.single['version'], 3);
      await verifyState(tester);
      await editSaved(tester);
      await input(tester, measurement(LactationMethod.nurse), '0');
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(
        (transport.records.single['observation'] as Map)['duration_minutes'],
        0,
      );
      expect(transport.records.single['version'], 4);
      await verifyState(tester);
      await editSaved(tester);
      await tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      final picker = find.byKey(const ValueKey('momcozy-time-picker'));
      final strings = MaterialLocalizations.of(tester.element(picker));
      await verifyState(tester);
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
        await verifyState(tester);
      }
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      await input(tester, fields.first, '05');
      await input(tester, fields.last, '00');
      await tap(
        tester,
        find.descendant(
          of: picker,
          matching: find.text(strings.postMeridiemAbbreviation),
        ),
      );
      await verifyState(tester);
      await tap(
        tester,
        find.descendant(of: picker, matching: find.text(strings.okButtonLabel)),
      );
      expect(draft(tester).occurredAt.hour, 17);
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(controller(tester).validationErrors, {
        'occurred_at': 'future_time',
      });
      expect(transport.records.single['version'], 4);
      await verifyState(tester);
      await tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
      }
      await tap(
        tester,
        find.descendant(
          of: picker,
          matching: find.text(strings.anteMeridiemAbbreviation),
        ),
      );
      await verifyState(tester);
      await input(tester, fields.first, '08');
      await input(tester, fields.last, '00');
      await verifyState(tester);
      await tap(
        tester,
        find.descendant(of: picker, matching: find.text(strings.okButtonLabel)),
      );
      expect(draft(tester).occurredAt.hour, 8);
      expect(controller(tester).validationErrors, isEmpty);
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(transport.records.single['version'], 5);
      await verifyState(tester);
      await editSaved(tester);
      await tap(tester, find.text('Back to records'));
      await verifyState(tester);
      await tap(tester, find.text('Keep editing'));
      expect(controller(tester).draft, isNotNull);
      await verifyState(tester);
      await tap(tester, find.text('Back to records'));
      await tap(tester, find.text('Leave'));
      expect(controller(tester).draft, isNull);
      expect(transport.records.single['version'], 5);
      await verifyState(tester);
      await editSaved(tester);
      await verifyState(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await verifyState(tester);
      await tap(tester, find.text('Leave'));
      expect(transport.records.single['version'], 5);
      await verifyState(tester, route: '/more');
      if (find.byType(LactationPanel).evaluate().isNotEmpty) {
        await closePanel(tester);
      }
      await verifyState(tester, route: '/more');
      await tester.pumpAndSettle();
      await verifyState(tester, route: '/more');
    });
  }
}
