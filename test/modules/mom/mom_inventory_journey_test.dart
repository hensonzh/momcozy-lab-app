import 'dart:async';
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
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 844);
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

  Future<void> verifyState(WidgetTester tester, {String route = '/me/lactation'}) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'inventory Mom lactation create edit delete restore and home refresh',
    (tester) async {
      await mount(tester);
      await verifyState(tester, route: '/me');
      router.push('/me/lactation?create=1');
      await tester.pumpAndSettle();
      await verifyState(tester);
      final measurement = find.byKey(
        const ValueKey('lactation-measurement-pump'),
      );
      await tester.enterText(measurement, '2001');
      await tap(tester, find.text('Save this record'));
      expect(transport.records, isEmpty);
      await verifyState(tester);
      await tester.enterText(measurement, '80');
      await tap(tester, find.text('Right side'));
      await verifyState(tester);
      transport.failWrite = true;
      await tap(tester, find.text('Save this record'));
      expect(
        find.text('Your save has not been confirmed. Please try again.'),
        findsOneWidget,
      );
      await verifyState(tester);
      transport.failWrite = false;
      await tap(tester, find.text('Try saving again'));
      expect(transport.records, hasLength(1));
      expect(find.text('Record saved.'), findsOneWidget);
      await verifyState(tester);
      await tap(tester, find.byTooltip('Close feeding and pumping records'));
      await verifyState(tester, route: '/me');
      router.push('/me/lactation');
      await tester.pumpAndSettle();
      const milkRoute = '/me/lactation';
      await verifyState(tester, route: milkRoute);
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      await verifyState(tester, route: milkRoute);
      await tester.enterText(measurement, '95');
      await tap(tester, find.text('Save changes'));
      expect((transport.records.single['observation'] as Map)['volume_ml'], 95);
      await verifyState(tester, route: milkRoute);
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-delete-inventory-milk-1')),
      );
      expect(transport.records, isEmpty);
      await verifyState(tester, route: milkRoute);
      transport.failWrite = true;
      await tap(tester, find.text('Undo'));
      await verifyState(tester, route: milkRoute);
      transport.failWrite = false;
      await tap(tester, find.text('Undo'));
      expect(transport.records, hasLength(1));
      await verifyState(tester, route: milkRoute);
      await tap(tester, find.byTooltip('Close feeding and pumping records'));
      await verifyState(tester, route: '/me');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory Mom AI card to Momcozy AI draft', (tester) async {
    await mount(tester);
    await tap(tester, find.text('Chat with Momcozy AI'));
    await verifyState(tester, route: '/');
    expect(transport.postedBodies, isEmpty);
    expect(
      find.text('I\'d like to talk about feeding and recovery today.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('inventory Mom nursing optional fields time picker and discard', (
    tester,
  ) async {
    await mount(tester);
    router.push('/me/lactation');
    await tester.pumpAndSettle();
    const route = '/me/lactation';
    await verifyState(tester, route: route);
    await tap(tester, find.text('Add a record'));
    await tap(tester, find.text('Nursing'));
    await verifyState(tester, route: route);
    final measure = find.byKey(const ValueKey('lactation-measurement-nurse'));
    await tester.enterText(measure, '241');
    await tap(tester, find.text('Save this record'));
    await verifyState(tester, route: route);
    await tester.enterText(measure, '12');
    await tap(tester, find.text('Feelings and notes'));
    await tap(tester, find.text('Full'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      'I want to remember how this feeding felt.',
    );
    await verifyState(tester, route: route);
    await tap(
      tester,
      find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
    );
    await verifyState(tester, route: route);
    final strings = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
    await verifyState(tester, route: route);
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.first, '99');
    await tap(tester, find.text(strings.okButtonLabel));
    await verifyState(tester, route: route);
    await tap(
      tester,
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text(strings.cancelButtonLabel),
      ),
    );
    await tap(tester, find.text('Cancel'));
    await verifyState(tester, route: route);
    await tap(tester, find.text('Keep editing'));
    await verifyState(tester, route: route);
    transport.writeGate = Completer<void>();
    await tester.tap(find.text('Save this record'));
    await tester.pump();
    await verifyState(tester, route: route);
    transport.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(transport.records, hasLength(1));
    expect(
      (transport.records.single['observation'] as Map)['duration_minutes'],
      12,
    );
    await verifyState(tester, route: route);
    await tap(tester, find.text('Add a record'));
    await tap(tester, find.text('Cancel'));
    await tap(tester, find.text('Leave'));
    await verifyState(tester, route: route);
    expect(transport.records, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'inventory Mom trend period toggles with recorded and missing days',
    (tester) async {
      await mount(
        tester,
        prepare: (t) {
          for (final day in [0, 1, 2, 4, 6, 7, 14, 20, 29]) {
            t.seedMilk({
              'method': 'pump',
              'side': 'left',
              'volume_ml': 60 + day * 3,
              'occurred_at': inventoryMomNow
                  .subtract(Duration(days: day))
                  .toIso8601String(),
            });
          }
        },
      );
      const route = '/me/lactation';
      router.push('/me/lactation');
      await tester.pumpAndSettle();
      await verifyState(tester, route: route);
      await tap(tester, find.text('30 days'));
      await verifyState(tester, route: route);
      await tap(tester, find.text('7 days'));
      await verifyState(tester, route: route);
      await tap(tester, find.byTooltip('Close feeding and pumping records'));
      await verifyState(tester, route: '/me');
      expect(transport.mutationPaths, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory Mom milk conflict uncertain close and failed delete', (
    tester,
  ) async {
    await mount(
      tester,
      prepare: (t) => t.seedMilk({
        'method': 'pump',
        'side': 'left',
        'volume_ml': 60,
        'occurred_at': inventoryMomNow.toIso8601String(),
      }),
    );
    const route = '/me/lactation';
    router.push('/me/lactation');
    await tester.pumpAndSettle();
    await tap(
      tester,
      find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('lactation-measurement-pump')),
      '70',
    );
    transport.failWrite = true;
    transport.failureStatus = 409;
    await tap(tester, find.text('Save changes'));
    await verifyState(tester, route: route);
    await tap(tester, find.text('Reload'));
    await verifyState(tester, route: route);
    await tap(tester, find.text('Leave'));
    await verifyState(tester, route: route);
    await tap(
      tester,
      find.byKey(const ValueKey('lactation-delete-inventory-milk-1')),
    );
    expect(transport.records, hasLength(1));
    await verifyState(tester, route: route);
    transport.failureStatus = 503;
    await tap(tester, find.text('Add a record'));
    await tester.enterText(
      find.byKey(const ValueKey('lactation-measurement-pump')),
      '50',
    );
    await tap(tester, find.text('Save this record'));
    await verifyState(tester, route: route);
    await tap(tester, find.byTooltip('Close feeding and pumping records'));
    await verifyState(tester, route: route);
    await tap(tester, find.text('Keep editing'));
    transport.failWrite = false;
    await tap(tester, find.text('Try saving again'));
    expect(transport.records, hasLength(2));
    await verifyState(tester, route: route);
    await tap(tester, find.byTooltip('Close feeding and pumping records'));
    await verifyState(tester, route: '/me');
    await tester.pumpWidget(const SizedBox());
  });
}
