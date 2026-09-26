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
import '../../support/mom_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  late MomInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  Future<void> mount(
    WidgetTester tester, {
    void Function(MomInventoryTransport)? prepare,
    bool loading = false,
  }) async {
    previous = null;
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

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/me/lactation',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source = 'test/goldens/ui_inventory/mom-journey-$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-journey-$state-393.png',
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
      'test': 'test/modules/mom/mom_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/mom-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  testWidgets(
    'inventory Mom lactation create edit delete restore and home refresh',
    (tester) async {
      await mount(tester);
      await capture(
        tester,
        'initial-home',
        'More → Me with no records',
        route: '/me',
      );
      router.push('/me/lactation?create=1');
      await tester.pumpAndSettle();
      await capture(
        tester,
        'milk-new-pump',
        'Home record lactation → new pump editor',
      );
      final measurement = find.byKey(
        const ValueKey('lactation-measurement-pump'),
      );
      await tester.enterText(measurement, '2001');
      await tap(tester, find.text('Save this record'));
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'milk-invalid-volume',
        'Submit out of range pump volume → validation',
      );
      await tester.enterText(measurement, '80');
      await tap(tester, find.text('Right side'));
      await capture(tester, 'milk-filled', 'Enter 80 ml and select right side');
      transport.failWrite = true;
      await tap(tester, find.text('Save this record'));
      expect(
        find.text('Your save has not been confirmed. Please try again.'),
        findsOneWidget,
      );
      await capture(
        tester,
        'milk-save-error',
        'Save → HTTP failure, draft locked pending retry',
      );
      transport.failWrite = false;
      await tap(tester, find.text('Try saving again'));
      expect(transport.records, hasLength(1));
      expect(find.text('Record saved.'), findsOneWidget);
      await capture(
        tester,
        'milk-modal-saved',
        'Retry save → actual record list and saved feedback',
      );
      await tap(tester, find.byTooltip('Close feeding and pumping records'));
      await capture(
        tester,
        'milk-home-refreshed',
        'Close saved panel → redesigned Me home',
        route: '/me',
      );
      router.push('/me/lactation');
      await tester.pumpAndSettle();
      const milkRoute = '/me/lactation';
      await capture(
        tester,
        'milk-history',
        'Home View records → standalone lactation history/trend',
        route: milkRoute,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      await capture(
        tester,
        'milk-history-edit',
        'History edit → record editor',
        route: milkRoute,
      );
      await tester.enterText(measurement, '95');
      await tap(tester, find.text('Save changes'));
      expect((transport.records.single['observation'] as Map)['volume_ml'], 95);
      await capture(
        tester,
        'milk-history-updated',
        'Save changed volume → refreshed history and update feedback',
        route: milkRoute,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-delete-inventory-milk-1')),
      );
      expect(transport.records, isEmpty);
      await capture(
        tester,
        'milk-history-deleted',
        'Delete record directly → deletion feedback with undo',
        route: milkRoute,
      );
      transport.failWrite = true;
      await tap(tester, find.text('Undo'));
      await capture(
        tester,
        'milk-restore-error',
        'Undo → API failure preserves undo entry',
        route: milkRoute,
      );
      transport.failWrite = false;
      await tap(tester, find.text('Undo'));
      expect(transport.records, hasLength(1));
      await capture(
        tester,
        'milk-history-restored',
        'Retry undo → record restored',
        route: milkRoute,
      );
      await tap(tester, find.byTooltip('Close feeding and pumping records'));
      await capture(
        tester,
        'milk-return-home',
        'Close history → redesigned Me home',
        route: '/me',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inventory Mom AI card to Momcozy AI draft', (tester) async {
    await mount(tester);
    await tap(tester, find.text('Chat with Momcozy AI'));
    await capture(
      tester,
      'ai-context-draft',
      'Me AI card → Momcozy AI with prefilled prompt, not sent',
      route: '/',
    );
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
    await capture(
      tester,
      'milk-history-empty',
      'Home View records → empty standalone lactation history',
      route: route,
    );
    await tap(tester, find.text('Add a record'));
    await tap(tester, find.text('Nursing'));
    await capture(
      tester,
      'nursing-empty',
      'History Add → switch to nursing form',
      route: route,
    );
    final measure = find.byKey(const ValueKey('lactation-measurement-nurse'));
    await tester.enterText(measure, '241');
    await tap(tester, find.text('Save this record'));
    await capture(
      tester,
      'nursing-duration-invalid',
      'Submit duration over limit → validation',
      route: route,
    );
    await tester.enterText(measure, '12');
    await tap(tester, find.text('Feelings and notes'));
    await tap(tester, find.text('Full'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      'I want to remember how this feeding felt.',
    );
    await capture(
      tester,
      'nursing-optional-filled',
      'Expand feeling and notes → enter optional observation',
      route: route,
    );
    await tap(
      tester,
      find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
    );
    await capture(
      tester,
      'nursing-time-picker',
      'Record time → time picker',
      route: route,
    );
    final strings = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
    await capture(
      tester,
      'nursing-time-input',
      'Time picker → keyboard time entry',
      route: route,
    );
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.first, '99');
    await tap(tester, find.text(strings.okButtonLabel));
    await capture(
      tester,
      'nursing-time-invalid',
      'Invalid hour → time picker error',
      route: route,
    );
    await tap(
      tester,
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text(strings.cancelButtonLabel),
      ),
    );
    await tap(tester, find.text('Cancel'));
    await capture(
      tester,
      'nursing-cancel-confirm',
      'Cancel record → discard confirmation',
      route: route,
    );
    await tap(tester, find.text('Keep editing'));
    await capture(
      tester,
      'nursing-cancel-retained',
      'Continue editing → all entered fields remain',
      route: route,
    );
    transport.writeGate = Completer<void>();
    await tester.tap(find.text('Save this record'));
    await tester.pump();
    await capture(
      tester,
      'nursing-saving',
      'Submit nursing while response pending → saving state',
      route: route,
    );
    transport.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(transport.records, hasLength(1));
    expect(
      (transport.records.single['observation'] as Map)['duration_minutes'],
      12,
    );
    await capture(
      tester,
      'nursing-saved',
      'Response received → saved nursing history',
      route: route,
    );
    await tap(tester, find.text('Add a record'));
    await tap(tester, find.text('Cancel'));
    await tap(tester, find.text('Leave'));
    await capture(
      tester,
      'nursing-new-discarded',
      'Cancel another new record and discard → existing history unchanged',
      route: route,
    );
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
      await capture(
        tester,
        'trend-seven-days',
        'Home history → seven-day measured curve with gaps',
        route: route,
      );
      await tap(tester, find.text('30 days'));
      await capture(
        tester,
        'trend-thirty-days',
        'Select 30 days → expanded period and older measurements',
        route: route,
      );
      await tap(tester, find.text('7 days'));
      await capture(
        tester,
        'trend-seven-days-return',
        'Return to 7 days → shorter curve',
        route: route,
      );
      await tap(tester, find.byTooltip('Close feeding and pumping records'));
      await capture(
        tester,
        'trend-return-home',
        'Close trend → redesigned Me home',
        route: '/me',
      );
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
    await capture(
      tester,
      'milk-conflict',
      'Edit saved milk and receive conflict → draft preserved',
      route: route,
    );
    await tap(tester, find.text('Reload'));
    await capture(
      tester,
      'milk-conflict-reload-confirm',
      'Reload conflicted milk → discard confirmation',
      route: route,
    );
    await tap(tester, find.text('Leave'));
    await capture(
      tester,
      'milk-conflict-reloaded',
      'Discard conflict draft → latest saved list',
      route: route,
    );
    await tap(
      tester,
      find.byKey(const ValueKey('lactation-delete-inventory-milk-1')),
    );
    expect(transport.records, hasLength(1));
    await capture(
      tester,
      'milk-delete-failed',
      'Delete rejected → record stays visible with error',
      route: route,
    );
    transport.failureStatus = 503;
    await tap(tester, find.text('Add a record'));
    await tester.enterText(
      find.byKey(const ValueKey('lactation-measurement-pump')),
      '50',
    );
    await tap(tester, find.text('Save this record'));
    await capture(
      tester,
      'milk-uncertain-save',
      'Unavailable create response → uncertain result and retry controls',
      route: route,
    );
    await tap(tester, find.byTooltip('Close feeding and pumping records'));
    await capture(
      tester,
      'milk-uncertain-leave-confirm',
      'Close uncertain record → reconciliation warning',
      route: route,
    );
    await tap(tester, find.text('Keep editing'));
    transport.failWrite = false;
    await tap(tester, find.text('Try saving again'));
    expect(transport.records, hasLength(2));
    await capture(
      tester,
      'milk-uncertain-retried',
      'Retry same pending save → saved list',
      route: route,
    );
    await tap(tester, find.byTooltip('Close feeding and pumping records'));
    await capture(
      tester,
      'milk-uncertain-return-home',
      'Return from reconciled save → Me home',
      route: '/me',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
