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
import 'package:momcozy_flutter_app/domain/lactation/lactation_record.dart';
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

  for (final narrow in [false, true]) {
    testWidgets('inventory milk controls ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await verifyState(tester, route: '/more');
      router.push('/me/lactation?create=1');
      await tester.pumpAndSettle();
      await verifyState(tester);
      await tap(tester, find.text('Right side'));
      expect(draft(tester).side, BreastSide.right);
      await verifyState(tester);
      await tap(tester, find.text('Left side'));
      expect(draft(tester).side, BreastSide.left);
      await verifyState(tester);
      await input(tester, measurement(LactationMethod.pump), '80.5');
      await verifyState(tester);
      await tap(tester, find.text('Nursing'));
      expect(draft(tester).method, LactationMethod.nurse);
      expect(draft(tester).measurement, isEmpty);
      await verifyState(tester);
      await input(tester, measurement(LactationMethod.nurse), '12');
      await verifyState(tester);
      await tap(tester, find.text('Pumping'));
      expect(draft(tester).measurement, isEmpty);
      await verifyState(tester);
      await input(tester, measurement(LactationMethod.pump), '80.5');
      await tap(tester, find.text('Feelings and notes'));
      await verifyState(tester);
      for (final option in breastComfortLabels.entries) {
        await tap(tester, find.text(option.value));
        expect(draft(tester).feeling, option.key);
        await verifyState(tester);
        await tap(tester, find.text(option.value));
        expect(draft(tester).feeling, isNull);
        await verifyState(tester);
      }
      await tap(tester, find.text('Comfortable'));
      await verifyState(tester);
      final note = find.widgetWithText(TextFormField, 'Notes (optional)');
      await input(tester, note, 'Left side feels comfortable this time.');
      expect(draft(tester).note, 'Left side feels comfortable this time.');
      await verifyState(tester);
      await input(tester, note, '');
      expect(draft(tester).note, isEmpty);
      await verifyState(tester);
      await input(tester, note, 'Left side feels comfortable this time.');
      await tap(tester, find.text('Feelings and notes'));
      await verifyState(tester);
      await tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      await verifyState(tester);
      final picker = find.byKey(const ValueKey('momcozy-time-picker'));
      final strings = MaterialLocalizations.of(tester.element(picker));
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
        await verifyState(tester);
      }
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      await input(tester, fields.first, '12');
      await input(tester, fields.last, '34');
      await verifyState(tester);
      await tap(
        tester,
        find.descendant(of: picker, matching: find.text(strings.okButtonLabel)),
      );
      expect(draft(tester).occurredAt.hour, 12);
      expect(draft(tester).occurredAt.minute, 34);
      await verifyState(tester);
      await tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      await verifyState(tester);
      await tap(
        tester,
        find.descendant(
          of: picker,
          matching: find.text(strings.cancelButtonLabel),
        ),
      );
      expect(draft(tester).occurredAt.hour, 12);
      expect(draft(tester).occurredAt.minute, 34);
      await verifyState(tester);
      expect(transport.records, isEmpty);
      await tap(tester, find.text('Save this record'));
      expect(transport.records, hasLength(1));
      expect(find.text('Record saved.'), findsOneWidget);
      await verifyState(tester);
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      final saved = draft(tester);
      expect(saved.method, LactationMethod.pump);
      expect(saved.side, BreastSide.left);
      expect(double.parse(saved.measurement), 80.5);
      expect(saved.feeling, BreastComfort.comfortable);
      expect(saved.note, 'Left side feels comfortable this time.');
      expect(saved.occurredAt.hour, 12);
      expect(saved.occurredAt.minute, 34);
      await verifyState(tester);
      await tap(tester, find.text('Nursing'));
      expect(draft(tester).measurement, isEmpty);
      expect(draft(tester).feeling, BreastComfort.comfortable);
      expect(draft(tester).note, saved.note);
      await verifyState(tester);
      await tap(tester, find.text('Save changes'));
      expect(transport.records, hasLength(1));
      expect(transport.records.single['version'], 2);
      expect(
        (transport.records.single['observation'] as Map)['duration_minutes'],
        isNull,
      );
      expect(find.text('Record updated.'), findsOneWidget);
      await verifyState(tester);
      await closePanel(tester);
      await verifyState(tester, route: '/more');
      router.push('/me/lactation');
      await tester.pumpAndSettle();
      const route = '/me/lactation';
      await verifyState(tester, route: route);
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      expect(draft(tester).method, LactationMethod.nurse);
      expect(draft(tester).measurement, isEmpty);
      expect(draft(tester).note, saved.note);
      await verifyState(tester, route: route);
      await tap(tester, find.text('Cancel'));
      await verifyState(tester, route: route);
      await tap(tester, find.text('Leave'));
      expect(transport.records.single['version'], 2);
      await verifyState(tester, route: route);
      await closePanel(tester);
      await verifyState(tester, route: '/more');
      await tester.pumpAndSettle();
      await verifyState(tester, route: '/more');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
