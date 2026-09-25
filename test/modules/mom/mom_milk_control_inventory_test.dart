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
  String? previous;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    void Function(MomInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double scale = 1,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    variant = '${width.toInt()}-${scale.toInt()}x';
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
        'assets/images/mom_home/expert_group.png',
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
    final source =
        'test/goldens/ui_inventory/mom-milk-control-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/mom-milk-control-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → existing lactation deep link',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test': 'test/modules/mom/mom_milk_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/mom-milk-control-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
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
      await capture(tester, 'home-entry', 'Authenticated More', route: '/more');
      router.push('/me/lactation?create=1');
      await tester.pumpAndSettle();
      await capture(tester, 'pump-empty', 'Home record once → pump editor');
      await tap(tester, find.text('Right side'));
      expect(draft(tester).side, BreastSide.right);
      await capture(
        tester,
        'side-right',
        'Select right breast → right volume label',
      );
      await tap(tester, find.text('Left side'));
      expect(draft(tester).side, BreastSide.left);
      await capture(
        tester,
        'side-left',
        'Select left breast → left volume label',
      );
      await input(tester, measurement(LactationMethod.pump), '80.5');
      await capture(
        tester,
        'pump-decimal',
        'Enter decimal pump volume 80.5 ml',
      );
      await tap(tester, find.text('Nursing'));
      expect(draft(tester).method, LactationMethod.nurse);
      expect(draft(tester).measurement, isEmpty);
      await capture(
        tester,
        'nurse-switch-cleared',
        'Switch pump to nurse → measurement cleared and minutes shown',
      );
      await input(tester, measurement(LactationMethod.nurse), '12');
      await capture(
        tester,
        'nurse-duration',
        'Enter nursing duration 12 minutes',
      );
      await tap(tester, find.text('Pumping'));
      expect(draft(tester).measurement, isEmpty);
      await capture(
        tester,
        'pump-switch-cleared',
        'Switch back to pump → nursing number cleared',
      );
      await input(tester, measurement(LactationMethod.pump), '80.5');
      await tap(tester, find.text('Feelings and notes'));
      await capture(tester, 'optional-open', 'Expand breast comfort and note');
      for (final option in breastComfortLabels.entries) {
        await tap(tester, find.text(option.value));
        expect(draft(tester).feeling, option.key);
        await capture(
          tester,
          'comfort-${option.key.name}',
          'Select breast comfort ${option.value}',
        );
        await tap(tester, find.text(option.value));
        expect(draft(tester).feeling, isNull);
        await capture(
          tester,
          'comfort-${option.key.name}-cleared',
          'Tap ${option.value} again → comfort cleared',
        );
      }
      await tap(tester, find.text('Comfortable'));
      await capture(
        tester,
        'comfort-restored',
        'Restore comfortable breast feeling',
      );
      final note = find.widgetWithText(TextFormField, 'Notes (optional)');
      await input(tester, note, 'Left side feels comfortable this time.');
      expect(draft(tester).note, 'Left side feels comfortable this time.');
      await capture(tester, 'note-filled', 'Enter optional note');
      await input(tester, note, '');
      expect(draft(tester).note, isEmpty);
      await capture(tester, 'note-cleared', 'Clear optional note');
      await input(tester, note, 'Left side feels comfortable this time.');
      await tap(tester, find.text('Feelings and notes'));
      await capture(
        tester,
        'optional-collapsed',
        'Collapse filled optional fields → filled indicator remains',
      );
      await tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      await capture(tester, 'time-open', 'Open record time picker');
      final picker = find.byKey(const ValueKey('momcozy-time-picker'));
      final strings = MaterialLocalizations.of(tester.element(picker));
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputTimeModeButtonLabel));
        await capture(tester, 'time-input-mode', 'Time dial → manual input');
      }
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      await input(tester, fields.first, '12');
      await input(tester, fields.last, '34');
      await capture(
        tester,
        'time-valid-input',
        'Enter valid record time 12:34',
      );
      await tap(
        tester,
        find.descendant(of: picker, matching: find.text(strings.okButtonLabel)),
      );
      expect(draft(tester).occurredAt.hour, 12);
      expect(draft(tester).occurredAt.minute, 34);
      await capture(
        tester,
        'time-accepted',
        'Confirm valid time → editor displays 12:34',
      );
      await tap(
        tester,
        find.widgetWithIcon(OutlinedButton, Icons.schedule_rounded),
      );
      await capture(
        tester,
        'time-reopened',
        'Reopen time picker → accepted time retained',
      );
      await tap(
        tester,
        find.descendant(
          of: picker,
          matching: find.text(strings.cancelButtonLabel),
        ),
      );
      expect(draft(tester).occurredAt.hour, 12);
      expect(draft(tester).occurredAt.minute, 34);
      await capture(
        tester,
        'time-cancelled',
        'Cancel picker → accepted time unchanged',
      );
      expect(transport.records, isEmpty);
      await tap(tester, find.text('Save this record'));
      expect(transport.records, hasLength(1));
      expect(find.text('Record saved.'), findsOneWidget);
      await capture(
        tester,
        'pump-saved',
        'Save pump through production repository → list and saved feedback',
      );
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
      await capture(
        tester,
        'pump-reopened',
        'Edit saved pump → all fields retained and optional section expanded',
      );
      await tap(tester, find.text('Nursing'));
      expect(draft(tester).measurement, isEmpty);
      expect(draft(tester).feeling, BreastComfort.comfortable);
      expect(draft(tester).note, saved.note);
      await capture(
        tester,
        'saved-switch-to-nurse',
        'Switch saved pump to nursing → clear numeric value, preserve side, note and comfort',
      );
      await tap(tester, find.text('Save changes'));
      expect(transport.records, hasLength(1));
      expect(transport.records.single['version'], 2);
      expect(
        (transport.records.single['observation'] as Map)['duration_minutes'],
        isNull,
      );
      expect(find.text('Record updated.'), findsOneWidget);
      await capture(
        tester,
        'nurse-no-duration-saved',
        'Save converted nursing with optional duration unset → updated record',
      );
      await closePanel(tester);
      await capture(
        tester,
        'home-nursing-only',
        'Close saved nursing → More, without inventing milk amount',
        route: '/more',
      );
      router.push('/me/lactation');
      await tester.pumpAndSettle();
      const route = '/me/lactation';
      await capture(
        tester,
        'history',
        'Home View records → nursing history',
        route: route,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('lactation-edit-inventory-milk-1')),
      );
      expect(draft(tester).method, LactationMethod.nurse);
      expect(draft(tester).measurement, isEmpty);
      expect(draft(tester).note, saved.note);
      await capture(
        tester,
        'history-reopened',
        'History Edit → saved nursing with empty duration and retained note',
        route: route,
      );
      await tap(tester, find.text('Cancel'));
      await capture(
        tester,
        'cancel-confirm',
        'Cancel unchanged lactation editor → confirmation still shown',
        route: route,
      );
      await tap(tester, find.text('Leave'));
      expect(transport.records.single['version'], 2);
      await capture(
        tester,
        'cancel-return-history',
        'Confirm leave → history retains version 2',
        route: route,
      );
      await closePanel(tester);
      await capture(
        tester,
        'home-return',
        'History close → More',
        route: '/more',
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        'more-return',
        'Bottom More → original tab',
        route: '/more',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
